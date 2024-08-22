import os

import pytest

from utils import EthAccounts, Faucet, NeonChainWeb3Client


@pytest.fixture(scope="class")
def web3_client():
    print(f"Proxy IP: {os.environ.get('PROXY_IP', '')}")
    return NeonChainWeb3Client(f"http://{os.environ.get('PROXY_IP', '')}:9090/solana")


@pytest.fixture(scope="class")
def faucet(web3_client) -> Faucet:
    return Faucet(f"http://{os.environ.get('PROXY_IP', '')}:3333", web3_client)


@pytest.fixture(scope="class")
def accounts(web3_client, faucet):
    return EthAccounts(web3_client, faucet)


@pytest.fixture(scope="function")
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
    print(f"Pool manager address: {contract.address}")
    yield contract


@pytest.fixture(scope="function")
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
    print(f"V4 Router address: {contract.address}")
    yield contract, pool_manager


@pytest.fixture(scope="function")
def position_manager(accounts, pool_manager, web3_client):
    contract, _ = web3_client.deploy_and_get_contract(
        contract="lib/v4-core/src/test/PoolModifyLiquidityTest.sol",
        version="0.8.26",
        contract_name="PoolModifyLiquidityTest",
        account=accounts[0],
        constructor_args=[pool_manager.address],
    )
    print(f"Position manager address: {contract.address}")
    yield contract


v4_router_test_contracts = [
    "V4Router.t.sol",
    "V4Router2.t.sol",
    "V4Router3.t.sol",
    "V4Router4.t.sol",
    "V4Router5.t.sol",
    "V4Router6.t.sol",
    "V4Router7.t.sol",
    "V4Router8.t.sol",
    "V4Router9.t.sol",
]


@pytest.fixture(scope="function")
def v4_router_test(request, accounts, v4_router, position_manager, web3_client):
    v4, pool_manager = v4_router
    deployed_contracts = dict()

    contract_name = ""
    if request.node.get_closest_marker("contract_filename"):
        contract_name = request.node.get_closest_marker("contract_filename").kwargs.get("name", "")

    for name in v4_router_test_contracts if contract_name == "" else [contract_name]:
        contract, _ = web3_client.deploy_and_get_contract(
            contract=f"test/router/{name}",
            version="0.8.26",
            contract_name="V4RouterTest",
            account=accounts[0],
            constructor_args=[v4.address, pool_manager.address, position_manager.address],
            import_remapping={
                "forge-std": f"{os.getcwd()}/lib/v4-core/lib/forge-std/src",
                "solmate/": f"{os.getcwd()}/lib/permit2/lib/solmate/",
                "permit2/": f"{os.getcwd()}/lib/permit2/",
            },
        )
        deployed_contracts[name] = contract
    yield deployed_contracts
