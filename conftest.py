import inspect
import json
import logging
import os
import pathlib
import random
import sys
import time
import typing as tp
from dataclasses import dataclass
from enum import Enum

import base58
import pytest
from _pytest.config import Config
from _pytest.config.argparsing import Parser
from requests import Session
from solders.keypair import Keypair

from utils import EthAccounts, Faucet, NeonChainWeb3Client, Web3Client

LOG = logging.getLogger(__name__)

TestGroup = tp.Literal[
    "economy",
    "basic",
    "tracer",
    "services",
    "oz",
    "ui",
    "evm",
    "compiler_compatibility",
]

TEST_GROUPS: tp.Tuple[TestGroup, ...] = tp.get_args(TestGroup)


class EnvName(str, Enum):
    NIGHT_STAND = "night-stand"
    RELEASE_STAND = "release-stand"
    MAINNET = "mainnet"
    DEVNET = "devnet"
    TESTNET = "testnet"
    LOCAL = "local"
    TERRAFORM = "terraform"
    GETH = "geth"
    TRACER_CI = "tracer_ci"
    CUSTOM = "custom"


@dataclass
class EnvironmentConfig:
    name: EnvName
    evm_loader: str
    proxy_url: str
    tracer_url: str
    solana_url: str
    faucet_url: str
    network_ids: dict
    spl_neon_mint: str
    neon_erc20wrapper_address: str
    use_bank: bool
    eth_bank_account: str
    neonpass_url: str = ""
    ws_subscriber_url: str = ""
    account_seed_version: str = "\3"


def pytest_addoption(parser: Parser):
    parser.addoption(
        "--network",
        action="store",
        choices=[env.value for env in EnvName],  # noqa
        default="night-stand",
        help="Which stand use",
    )
    parser.addoption(
        "--make-report",
        action="store_true",
        default=False,
        help="Store tests result to file",
    )
    known_args = parser.parse_known_args(args=sys.argv[1:])
    test_group_required = True if known_args.make_report else False
    parser.addoption(
        "--test-group",
        choices=TEST_GROUPS,
        required=test_group_required,
        help="Test group",
    )

    parser.addoption("--envs", action="store", default="envs.json", help="Filename with environments")
    parser.addoption(
        "--keep-error-log",
        action="store_true",
        default=False,
        help=f"Don't clear file",
    )


def pytest_sessionstart(session: pytest.Session):
    """Hook for clearing the error log used by the Slack notifications utility"""
    keep_error_log = session.config.getoption(name="--keep-error-log", default=False)
    if not keep_error_log:
        pass


def pytest_configure(config: Config):
    solana_url_env_vars = ["SOLANA_URL", "DEVNET_INTERNAL_RPC", "MAINNET_INTERNAL_RPC"]
    network_name = config.getoption("--network")
    envs_file = config.getoption("--envs")
    with open(pathlib.Path().parent.parent / envs_file, "r+") as f:
        environments = json.load(f)
    assert network_name in environments, f"Environment {network_name} doesn't exist in envs.json"
    env = environments[network_name]
    env["name"] = EnvName(network_name)
    if network_name in ["devnet", "tracer_ci"]:
        for solana_env_var in solana_url_env_vars:
            if solana_env_var in os.environ and os.environ[solana_env_var]:
                env["solana_url"] = os.environ.get(solana_env_var)
                break
        if "PROXY_URL" in os.environ and os.environ["PROXY_URL"]:
            env["proxy_url"] = os.environ.get("PROXY_URL")
        if "DEVNET_FAUCET_URL" in os.environ and os.environ["DEVNET_FAUCET_URL"]:
            env["faucet_url"] = os.environ.get("DEVNET_FAUCET_URL")
    if "use_bank" not in env:
        env["use_bank"] = False
    if "eth_bank_account" not in env:
        env["eth_bank_account"] = ""

    # Set envs for integration/tests/neon_evm project
    if "SOLANA_URL" not in os.environ or not os.environ["SOLANA_URL"]:
        os.environ["SOLANA_URL"] = env["solana_url"]
    if "EVM_LOADER" not in os.environ or not os.environ["EVM_LOADER"]:
        os.environ["EVM_LOADER"] = env["evm_loader"]
    if "NEON_TOKEN_MINT" not in os.environ or not os.environ["NEON_TOKEN_MINT"]:
        os.environ["NEON_TOKEN_MINT"] = env["spl_neon_mint"]
    if "CHAIN_ID" not in os.environ or not os.environ["CHAIN_ID"]:
        os.environ["CHAIN_ID"]: env["network_ids"]["neon"]

    if network_name == "terraform":
        env["solana_url"] = env["solana_url"].replace("<solana_ip>", os.environ.get("SOLANA_IP"))
        env["proxy_url"] = env["proxy_url"].replace("<proxy_ip>", os.environ.get("PROXY_IP"))
        env["faucet_url"] = env["faucet_url"].replace("<proxy_ip>", os.environ.get("PROXY_IP"))
    config.environment = EnvironmentConfig(**env)


@pytest.fixture(scope="session")
def env_name(pytestconfig: Config) -> EnvName:
    return pytestconfig.environment.name  # noqa


@pytest.fixture(scope="session")
def operator_keypair():
    with open("operator-keypair.json", "r") as key:
        secret_key = json.load(key)[:32]
        return Keypair.from_secret_key(secret_key)


@pytest.fixture(scope="session")
def evm_loader_keypair():
    with open("evm_loader-keypair.json", "r") as key:
        secret_key = json.load(key)[:32]
        return Keypair.from_secret_key(secret_key)


@pytest.fixture(scope="session", autouse=True)
def allure_environment(pytestconfig: Config, web3_client_session: NeonChainWeb3Client):
    opts = {}
    network_name = pytestconfig.getoption("--network")
    if network_name != "geth" and network_name != "mainnet" and "neon_evm" not in os.getenv("PYTEST_CURRENT_TEST"):
        opts = {
            "Network": pytestconfig.environment.proxy_url,
            "Proxy.Version": web3_client_session.get_proxy_version()["result"],
            "EVM.Version": web3_client_session.get_evm_version()["result"],
            "CLI.Version": web3_client_session.get_cli_version()["result"],
        }

    yield opts


@pytest.fixture(scope="session")
def web3_client_session(pytestconfig: Config) -> NeonChainWeb3Client:
    client = NeonChainWeb3Client(
        pytestconfig.environment.proxy_url,
        tracer_url=pytestconfig.environment.tracer_url,
    )
    return client


@pytest.fixture(scope="session", autouse=True)
def faucet(pytestconfig: Config, web3_client_session) -> Faucet:
    return Faucet(pytestconfig.environment.faucet_url, web3_client_session)


@pytest.fixture(scope="session")
def accounts_session(pytestconfig: Config, web3_client_session, faucet, eth_bank_account):
    accounts = EthAccounts(web3_client_session, faucet, eth_bank_account)
    return accounts


class JsonRPCSession(Session):
    def __init__(self, url):
        super(JsonRPCSession, self).__init__()
        self.url = url

    def send_rpc(
        self,
        method: str,
        params: tp.Optional[tp.Any] = None,
        req_type: tp.Optional[str] = None,
    ) -> tp.Dict:
        req_id = random.randint(0, 100)
        body = {"jsonrpc": "2.0", "method": method, "id": req_id}

        if req_type is not None:
            body["req_type"] = req_type

        if params:
            if not isinstance(params, (list, tuple)):
                params = [params]
            body["params"] = params

        resp = self.post(self.url, json=body, timeout=60)
        response_body = resp.json()
        if "result" not in response_body and "error" not in response_body:
            raise AssertionError("Request must contains 'result' or 'error' field")

        if "error" in response_body:
            assert "result" not in response_body, "Response can't contains error and result"
        if "error" not in response_body:
            assert response_body["id"] == req_id

        return response_body

    def get_contract_code(self, contract_address: str) -> str:
        response = self.send_rpc("eth_getCode", [contract_address, "latest"])
        return response["result"]

    def get_neon_trx_receipt(self, trx_hash: str) -> tp.Dict:
        return self.send_rpc("neon_getTransactionReceipt", params=[trx_hash.hex()])

    def get_solana_trx_by_neon(self, trx_hash: str) -> tp.Dict:
        return self.send_rpc("neon_getSolanaTransactionByNeonTransaction", params=[trx_hash.hex()])


def wait_finalized_block(rpc_client: JsonRPCSession, block_num: int):
    fin_block_num = block_num - 32
    while block_num > fin_block_num:
        time.sleep(1)
        response = rpc_client.send_rpc("neon_finalizedBlockNumber", [])
        fin_block_num = int(response["result"], 16)


NEON_AIRDROP_AMOUNT = 1_000


@pytest.fixture(scope="session")
def ws_subscriber_url(pytestconfig: tp.Any) -> tp.Optional[str]:
    return pytestconfig.environment.ws_subscriber_url


@pytest.fixture(scope="session")
def json_rpc_client(pytestconfig: Config) -> JsonRPCSession:
    return JsonRPCSession(pytestconfig.environment.proxy_url)


@pytest.fixture(scope="class")
def web3_client(request, web3_client_session):
    if inspect.isclass(request.cls):
        request.cls.web3_client = web3_client_session
    yield web3_client_session


@pytest.fixture(scope="session")
def web3_client_sol(pytestconfig: Config) -> tp.Union[Web3Client, None]:
    if "sol" in pytestconfig.environment.network_ids:
        client = Web3Client(f"{pytestconfig.environment.proxy_url}/sol")
        return client
    else:
        return None


@pytest.fixture(scope="session")
def web3_client_usdt(pytestconfig: Config) -> tp.Union[Web3Client, None]:
    if "usdt" in pytestconfig.environment.network_ids:
        return Web3Client(f"{pytestconfig.environment.proxy_url}/usdt")
    else:
        return None


@pytest.fixture(scope="session")
def bank_account(pytestconfig: Config) -> tp.Optional[Keypair]:
    account = None
    if pytestconfig.environment.use_bank:
        if pytestconfig.getoption("--network") == "devnet":
            private_key = os.environ.get("BANK_PRIVATE_KEY")
        elif pytestconfig.getoption("--network") == "mainnet":
            private_key = os.environ.get("BANK_PRIVATE_KEY_MAINNET")
        key = base58.b58decode(private_key)
        account = Keypair.from_secret_key(key)
    yield account


@pytest.fixture(scope="session")
def eth_bank_account(pytestconfig: Config, web3_client_session) -> tp.Optional[Keypair]:
    account = None
    if pytestconfig.environment.eth_bank_account != "":
        account = web3_client_session.eth.account.from_key(pytestconfig.environment.eth_bank_account)
    if pytestconfig.getoption("--network") == "mainnet":
        account = web3_client_session.eth.account.from_key(os.environ.get("ETH_BANK_PRIVATE_KEY_MAINNET"))
    yield account


@pytest.fixture(scope="class")
def accounts(request, accounts_session, web3_client_session, pytestconfig: Config, eth_bank_account):
    if inspect.isclass(request.cls):
        request.cls.accounts = accounts_session
    yield accounts_session
    if pytestconfig.getoption("--network") == "mainnet":
        if len(accounts_session.accounts_collector) > 0:
            for item in accounts_session.accounts_collector:
                web3_client_session.send_all_neons(item, eth_bank_account)
    accounts_session._accounts = []


@pytest.fixture(scope="class")
def pool_manager(accounts, web3_client):
    contract, _ = web3_client.deploy_and_get_contract(
        contract="lib/v4-core/src/PoolManager.sol",
        version="0.8.26",
        contract_name="PoolManager",
        account=accounts[0],
        import_remapping={
            "solmate/": f"{os.getcwd()}/lib/permit2/lib/solmate/",
        },
    )
    yield contract


@pytest.fixture(scope="class")
def v4_router(accounts, pool_manager, web3_client):
    contract, _ = web3_client.deploy_and_get_contract(
        contract="test/mocks/MockV4Router.sol",
        version="0.8.26",
        contract_name="MockV4Router",
        account=accounts[0],
        constructor_args=[pool_manager.address],
        import_remapping={
            "solmate/": f"{os.getcwd()}/lib/permit2/lib/solmate/",
        },
    )
    yield contract, pool_manager


@pytest.fixture(scope="class")
def position_manager(accounts, pool_manager, faucet, web3_client):
    contract, _ = web3_client.deploy_and_get_contract(
        contract="lib/v4-core/src/test/PoolModifyLiquidityTest.sol",
        version="0.8.26",
        contract_name="PoolModifyLiquidityTest",
        account=accounts[0],
        constructor_args=[pool_manager.address],
    )
    yield contract


@pytest.fixture(scope="class")
def v4_router_test(accounts, v4_router, position_manager, web3_client, faucet):
    v4, pool_manager = v4_router
    print(f"V4 address: {v4.address}")
    print(f"Pool manager address: {pool_manager.address}")
    print(f"Position manager address: {position_manager.address}")
    deployed_contracts = dict()
    for name in [
        "V4Router.t.sol",
        "V4Router2.t.sol",
        "V4Router3.t.sol",
        "V4Router4.t.sol",
        "V4Router5.t.sol",
        "V4Router6.t.sol",
        "V4Router7.t.sol",
        "V4Router8.t.sol",
        "V4Router9.t.sol",
    ]:
        contract, _ = web3_client.deploy_and_get_contract(
            contract=f"test/router/{name}",
            version="0.8.26",
            contract_name="V4RouterTest",
            account=accounts[0],
            constructor_args=[v4.address, pool_manager.address, position_manager.address],
            import_remapping={
                # "@uniswap/v4-core/": f"{os.getcwd()}/lib/v4-core/",
                "forge-std": f"{os.getcwd()}/lib/v4-core/lib/forge-std/src",
                "solmate/": f"{os.getcwd()}/lib/permit2/lib/solmate/",
                "permit2/": f"{os.getcwd()}/lib/permit2/",
            },
        )
        deployed_contracts[name] = contract
    print(f"Contracts: {deployed_contracts}")
    yield deployed_contracts
