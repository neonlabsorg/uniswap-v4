import json
import pathlib
import time
import typing as tp
import urllib
from decimal import Decimal
from enum import Enum

import eth_account.signers.local
import requests
import solcx
import web3
from eth_utils import keccak
from solcx import link_code


class Unit(Enum):
    WEI = "wei"
    KWEI = "kwei"
    MWEI = "mwei"
    GWEI = "gwei"
    MICRO_ETHER = "microether"
    MILLI_ETHER = "milliether"
    ETHER = "ether"

    def lower(self):
        return self.value


def wait_condition(func_cond, timeout_sec=15, delay=0.5):
    start_time = time.time()
    while True:
        if time.time() - start_time > timeout_sec:
            raise TimeoutError(f"The condition not reached within {timeout_sec} sec")
        try:
            if func_cond():
                break

        except Exception as e:
            print(f"Error during waiting: {e}")
        time.sleep(delay)
    return True


def get_contract_abi(name, compiled):
    for key in compiled.keys():
        if name == key.rsplit(":")[-1]:
            return compiled[key]


def get_contract_interface(
    contract: str,
    version: str,
    contract_name: tp.Optional[str] = None,
    import_remapping: tp.Optional[dict] = None,
    libraries: tp.Optional[dict] = None,
):
    if not contract.endswith(".sol"):
        contract += ".sol"
    if contract_name is None:
        if "/" in contract:
            contract_name = contract.rsplit("/", 1)[1].rsplit(".", 1)[0]
        else:
            contract_name = contract.rsplit(".", 1)[0]

    solcx.install_solc(version)
    if contract.startswith("/"):
        contract_path = pathlib.Path(contract)
    else:
        contract_path = (pathlib.Path.cwd() / "contracts" / f"{contract}").absolute()
        if not contract_path.exists():
            contract_path = (pathlib.Path.cwd() / f"{contract}").absolute()

    assert contract_path.exists(), f"Can't found contract: {contract_path}"

    compiled = solcx.compile_files(
        [contract_path],
        output_values=["abi", "bin"],
        solc_version=version,
        import_remappings=import_remapping,
        allow_paths=["."],
        optimize=True,
        optimize_runs=0,
        optimize_yul=False,
    )  # this allow_paths isn't very good...
    contract_interface = get_contract_abi(contract_name, compiled)
    if libraries:
        contract_interface["bin"] = link_code(contract_interface["bin"], libraries)

    return contract_interface


class InputTestConstants(Enum):
    NEW_USER_REQUEST_AMOUNT = 200
    DEFAULT_TRANSFER_AMOUNT = 0.1
    SAMPLE_AMOUNT = 0.5
    ROUND_DIGITS = 3


class Web3Client:
    def __init__(
        self,
        proxy_url: str,
        tracer_url: tp.Optional[tp.Any] = None,
        session: tp.Optional[tp.Any] = None,
    ):
        self._proxy_url = proxy_url
        self._tracer_url = tracer_url
        self._chain_id = None
        self._web3 = web3.Web3(web3.HTTPProvider(proxy_url, session=session, request_kwargs={"timeout": 30}))

    def __getattr__(self, item):
        return getattr(self._web3, item)

    @property
    def native_token_name(self):
        if self._proxy_url.split("/")[-1] != "solana":
            return self._proxy_url.split("/")[-1].upper()
        else:
            return "NEON"

    @property
    def chain_id(self):
        if self._chain_id is None:
            self._chain_id = self._web3.eth.chain_id
        return self._chain_id

    def _get_evm_info(self, method):
        resp = requests.post(
            self._proxy_url,
            json={"jsonrpc": "2.0", "method": method, "params": [], "id": 1},
        )
        resp.raise_for_status()
        try:
            body = resp.json()
            return body
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Failed to decode EVM info: {resp.text}")

    def get_neon_emulate(self, params):
        return requests.post(
            self._proxy_url,
            json={
                "jsonrpc": "2.0",
                "method": "neon_emulate",
                "params": [params],
                "id": 0,
            },
        ).json()

    def get_solana_trx_by_neon(self, tr_id: str):
        return requests.post(
            self._proxy_url,
            json={
                "jsonrpc": "2.0",
                "method": "neon_getSolanaTransactionByNeonTransaction",
                "params": [tr_id],
                "id": 0,
            },
        ).json()

    def get_transaction_by_hash(self, transaction_hash):
        try:
            return self._web3.eth.get_transaction(transaction_hash)
        except Exception:
            return None

    def gas_price(self):
        gas = self._web3.eth.gas_price
        return gas

    def create_account(self):
        return self._web3.eth.account.create()

    def get_block_number(self):
        return self._web3.eth.get_block_number()

    def get_block_number_by_id(self, block_identifier):
        return self._web3.eth.get_block(block_identifier)

    def get_nonce(
        self,
        address: tp.Union[eth_account.signers.local.LocalAccount, str],
        block: str = "pending",
    ):
        address = address if isinstance(address, str) else address.address
        return self._web3.eth.get_transaction_count(address, block)

    def wait_for_transaction_receipt(self, tx_hash, timeout=120):
        return self._web3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)

    def deploy_contract(
        self,
        from_: eth_account.signers.local.LocalAccount,
        abi,
        bytecode: str,
        gas: tp.Optional[int] = 0,
        gas_price: tp.Optional[int] = None,
        constructor_args: tp.Optional[tp.List] = None,
        value=0,
    ) -> web3.types.TxReceipt:
        """Proxy doesn't support send_transaction"""
        gas_price = gas_price or self.gas_price()
        constructor_args = constructor_args or []

        contract = self._web3.eth.contract(abi=abi, bytecode=bytecode)
        transaction = contract.constructor(*constructor_args).build_transaction(
            {
                "from": from_.address,
                "gas": gas,
                "gasPrice": gas_price,
                "nonce": self.get_nonce(from_),
                "value": value,
                "chainId": self.chain_id,
            }
        )

        if transaction["gas"] == 0:
            transaction["gas"] = self._web3.eth.estimate_gas(transaction)

        signed_tx = self._web3.eth.account.sign_transaction(transaction, from_.key)
        tx = self._web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        return self._web3.eth.wait_for_transaction_receipt(tx)

    def make_raw_tx(
        self,
        from_: tp.Union[str, eth_account.signers.local.LocalAccount],
        to: tp.Optional[tp.Union[str, eth_account.signers.local.LocalAccount]] = None,
        amount: tp.Optional[tp.Union[int, float, Decimal]] = None,
        gas: tp.Optional[int] = None,
        gas_price: tp.Optional[int] = None,
        nonce: tp.Optional[int] = None,
        chain_id: tp.Optional[int] = None,
        data: tp.Optional[tp.Union[str, bytes]] = None,
        estimate_gas=False,
    ) -> dict:
        if isinstance(from_, eth_account.signers.local.LocalAccount):
            transaction = {"from": from_.address}
        else:
            transaction = {"from": from_}

        if to:
            if isinstance(to, eth_account.signers.local.LocalAccount):
                transaction["to"] = to.address
            if isinstance(to, str):
                transaction["to"] = to
        if amount:
            transaction["value"] = amount
        if data:
            transaction["data"] = data
        if nonce is None:
            transaction["nonce"] = self.get_nonce(from_)
        else:
            transaction["nonce"] = nonce

        if chain_id is None:
            transaction["chainId"] = self.chain_id
        elif chain_id:
            transaction["chainId"] = chain_id

        if gas_price is None:
            gas_price = self.gas_price()
        transaction["gasPrice"] = gas_price
        if estimate_gas and not gas:
            gas = self._web3.eth.estimate_gas(transaction)
        if gas:
            transaction["gas"] = gas
        return transaction

    def send_transaction(
        self,
        account: eth_account.signers.local.LocalAccount,
        transaction: tp.Dict,
        gas_multiplier: tp.Optional[float] = None,  # fix for some event depends transactions
        timeout: int = 120,
    ) -> web3.types.TxReceipt:
        instruction_tx = self._web3.eth.account.sign_transaction(transaction, account.key)
        signature = self._web3.eth.send_raw_transaction(instruction_tx.raw_transaction)
        return self._web3.eth.wait_for_transaction_receipt(signature, timeout=timeout)

    def deploy_and_get_contract(
        self,
        contract: str,
        version: str,
        account: eth_account.signers.local.LocalAccount,
        contract_name: tp.Optional[str] = None,
        constructor_args: tp.Optional[tp.Any] = None,
        import_remapping: tp.Optional[dict] = None,
        libraries: tp.Optional[dict] = None,
        gas: tp.Optional[int] = 0,
        value=0,
    ) -> tp.Tuple[tp.Any, web3.types.TxReceipt]:
        contract_interface = get_contract_interface(
            contract,
            version,
            contract_name=contract_name,
            import_remapping=import_remapping,
            libraries=libraries,
        )

        contract_deploy_tx = self.deploy_contract(
            account,
            abi=contract_interface["abi"],
            bytecode=contract_interface["bin"],
            constructor_args=constructor_args,
            gas=gas,
            value=value,
        )

        contract = self.eth.contract(address=contract_deploy_tx["contractAddress"], abi=contract_interface["abi"])

        return contract, contract_deploy_tx

    @staticmethod
    def text_to_bytes32(text: str) -> bytes:
        return text.encode().ljust(32, b"\0")

    def call_function_at_address(self, contract_address, signature, args, result_types):
        calldata = decode_function_signature(signature, args)
        tx = {
            "data": calldata,
            "to": contract_address,
        }
        result = self._web3.eth.call(tx)
        return abi.decode(result_types, result)[0]

    def get_balance(
        self,
        address: tp.Union[str, eth_account.signers.local.LocalAccount],
        unit=Unit.WEI,
    ):
        if not isinstance(address, str):
            address = address.address
        balance = self._web3.eth.get_balance(address, "pending")
        if unit != Unit.WEI:
            balance = self._web3.from_wei(balance, unit.value)
        return balance

    def get_deployed_contract(
        self,
        address,
        contract_file,
        contract_name=None,
        solc_version="0.8.12",
        import_remapping: tp.Optional[dict] = None,
    ):
        contract_interface = helpers.get_contract_interface(
            contract_file, solc_version, contract_name, import_remapping=import_remapping
        )
        contract = self.eth.contract(address=address, abi=contract_interface["abi"])
        return contract

    def send_tokens(
        self,
        from_: eth_account.signers.local.LocalAccount,
        to: tp.Union[str, eth_account.signers.local.LocalAccount],
        value: int,
        gas: tp.Optional[int] = None,
        gas_price: tp.Optional[int] = None,
        nonce: int = None,
    ) -> web3.types.TxReceipt:
        transaction = self.make_raw_tx(
            from_, to, amount=value, gas=gas, gas_price=gas_price, nonce=nonce, estimate_gas=True
        )

        signed_tx = self.eth.account.sign_transaction(transaction, from_.key)
        tx = self.eth.send_raw_transaction(signed_tx.raw_transaction)
        return self.eth.wait_for_transaction_receipt(tx)

    def send_all_neons(
        self,
        from_: eth_account.signers.local.LocalAccount,
        to: tp.Union[str, eth_account.signers.local.LocalAccount],
        gas: tp.Optional[int] = None,
        gas_price: tp.Optional[int] = None,
        nonce: int = None,
    ) -> web3.types.TxReceipt:
        value = self.get_balance(from_.address)
        transaction = self.make_raw_tx(
            from_, to, amount=value, gas=gas, gas_price=gas_price, nonce=nonce, estimate_gas=True
        )
        transaction["value"] = float(value) - float(transaction["gas"] * transaction["gasPrice"] * 1.1)

        if transaction["value"] > 0:
            transaction["value"] = web3.Web3.to_wei(transaction["value"], Unit.WEI)
            signed_tx = self.eth.account.sign_transaction(transaction, from_.key)
            tx = self.eth.send_raw_transaction(signed_tx.rawTransaction)
            self.eth.wait_for_transaction_receipt(tx)
        else:
            LOG.info(f"Not enough funds to send all neons from {from_.address} account")

    @staticmethod
    def to_atomic_currency(amount):
        return web3.Web3.to_wei(amount, "ether")

    def to_main_currency(self, value):
        return web3.Web3.from_wei(value, "ether")

    def calculate_trx_gas(self, tx_receipt: web3.types.TxReceipt) -> int:
        tx = self._web3.eth.get_transaction(tx_receipt.transactionHash)
        gas_used_in_tx = tx_receipt.gasUsed * tx["gasPrice"]
        return gas_used_in_tx

    def get_token_usd_gas_price(self):
        resp = requests.post(
            self._proxy_url,
            json={
                "jsonrpc": "2.0",
                "method": "neon_gasPrice",
                "params": [],
                "id": 0,
            },
        ).json()
        return int(resp["result"]["tokenPriceUsd"], 16) / 100000

    def get_evm_info(self, method):
        resp = requests.post(
            self._proxy_url,
            json={"jsonrpc": "2.0", "method": method, "params": [], "id": 1},
        )
        resp.raise_for_status()
        try:
            body = resp.json()
            return body
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Failed to decode EVM info: {resp.text}")


class NeonChainWeb3Client(Web3Client):
    def __init__(
        self,
        proxy_url: str,
        tracer_url: tp.Optional[tp.Any] = None,
        session: tp.Optional[tp.Any] = None,
    ):
        super().__init__(proxy_url, tracer_url, session)

    def create_account_with_balance(
        self,
        faucet,
        amount: int = InputTestConstants.NEW_USER_REQUEST_AMOUNT.value,
    ):
        """Creates a new account with balance"""
        account = self.create_account()
        faucet.request_neon(account.address, amount=amount)
        return account

    def send_neon(
        self,
        from_: eth_account.signers.local.LocalAccount,
        to: tp.Union[str, eth_account.signers.local.LocalAccount],
        amount: tp.Union[int, float, Decimal],
        gas: tp.Optional[int] = None,
        gas_price: tp.Optional[int] = None,
        nonce: int = None,
    ) -> web3.types.TxReceipt:
        value = web3.Web3.to_wei(amount, "ether")
        return self.send_tokens(from_, to, value, gas, gas_price, nonce)


class Faucet:
    def __init__(
        self,
        faucet_url: str,
        web3_client: NeonChainWeb3Client,
        session: tp.Optional[tp.Any] = None,
    ):
        self._url = faucet_url
        self._session = session or requests.Session()
        self.web3_client = web3_client

    def request_neon(self, address: str, amount: int = 100) -> requests.Response:
        assert address.startswith("0x")
        url = urllib.parse.urljoin(self._url, "request_neon")
        balance_before = self.web3_client.get_balance(address)
        response = self._session.post(url, json={"amount": amount, "wallet": address})
        counter = 0
        while "Blockhash not found" in response.text and counter < 3:
            time.sleep(3)
            response = self._session.post(url, json={"amount": amount, "wallet": address})
            counter += 1
        assert response.ok, "Faucet returned error: {}, status code: {}, url: {}".format(
            response.text, response.status_code, response.url
        )
        wait_condition(lambda: self.web3_client.get_balance(address) > balance_before)
        return response


class EthAccounts:
    def __init__(self, web3_client: NeonChainWeb3Client, faucet):
        self._web3_client = web3_client
        self._faucet = faucet
        self._accounts = []
        self.accounts_collector = []

    def __getitem__(self, item):
        if len(self._accounts) < (item + 1):
            for _ in range(item + 1 - len(self._accounts)):
                account = self._web3_client.create_account_with_balance(self._faucet)

                self._accounts.append(account)
                self.accounts_collector.append(account)
        return self._accounts[item]

    def create_account(self, balance=InputTestConstants.NEW_USER_REQUEST_AMOUNT.value):
        if balance > 0:
            account = self._web3_client.create_account_with_balance(self._faucet, balance)
        else:
            account = self._web3_client.create_account()
        self.accounts_collector.append(account)
        return account


def get_selectors(abi):
    """Get functions signatures with params as keccak256 from contract abi"""
    selectors = []
    for function in filter(lambda item: item["type"] == "function", abi):
        input_types = ""
        for input in function["inputs"]:
            if "struct" in input["internalType"]:
                struct_name = input["name"]
                struct_types = ",".join(i["type"] for i in input["components"] if i["name"] != struct_name)
                input_types += "," + f"({struct_types})[]"
            else:
                input_types += "," + input["type"]

        input_types = input_types[1:]
        encoded_selector = f"{function['name']}({input_types})"
        selectors.append(keccak(text=encoded_selector)[:4])
    return selectors


def decode_function_signature(function_name: str, args=None) -> str:
    data = keccak(text=function_name)[:4]
    if args is not None:
        types = function_name.split("(")[1].split(")")[0].split(",")
        data += abi.encode(types, args)
    return "0x" + data.hex()
