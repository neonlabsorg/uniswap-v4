import pytest

from utils import EthAccounts, NeonChainWeb3Client, decode_function_signature


# @pytest.mark.usefixtures("accounts", "web3_client")
class TestV4Router:
    # web3_client: NeonChainWeb3Client
    # accounts: EthAccounts

    TEST_FUNCTIONS = [
        # ("V4Router.t.sol", "test_swapExactInputSingle_revertsForAmountOut()"),
        ("V4Router.t.sol", "test_swapExactInputSingle_zeroForOne_takeToMsgSender()"),
        # ("V4Router.t.sol", "test_swapExactInputSingle_zeroForOne_takeToRecipient()"),
        # (
        #     "V4Router.t.sol",
        #     "test_swapExactInputSingle_zeroForOne_takeAllToRouter()",
        # ),  # execution reverted: currency0 balance of router is not 0', '0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000
        # ("V4Router2.t.sol", "test_swapExactInputSingle_oneForZero()"),
        # (
        #     "V4Router2.t.sol",
        #     "test_swapExactInput_revertsForAmountOut()",
        # ),  # web3.exceptions.ContractLogicError: ('execution reverted', '0x')
        # ("V4Router2.t.sol", "test_swapExactIn_1Hop_zeroForOne()"),
        # ("V4Router2.t.sol", "test_swapExactIn_2Hops()"),
        # ("V4Router3.t.sol", "test_swapExactIn_3Hops()"),
        # ("V4Router3.t.sol", "test_swap_settleRouterBalance_swapOpenDelta()"),
        # ("V4Router3.t.sol", "test_nativeIn_swapExactInputSingle()"),
        # ("V4Router4.t.sol", "test_nativeOut_swapExactInputSingle()"),
        # ("V4Router4.t.sol", "test_nativeIn_swapExactIn_1Hop()"),
        # ("V4Router4.t.sol", "test_nativeOut_swapExactIn_1Hop()"),
        # ("V4Router4.t.sol", "test_nativeIn_swapExactIn_2Hops()"),
        # ("V4Router5.t.sol", "test_nativeOut_swapExactIn_2Hops()"),
        # ("V4Router5.t.sol", "test_swap_nativeIn_settleRouterBalance_swapOpenDelta()"),
        # ("V4Router6.t.sol", "test_swapExactOutputSingle_revertsForAmountIn()"),
        # ("V4Router6.t.sol", "test_swapExactOutputSingle_zeroForOne()"),
        # ("V4Router6.t.sol", "test_swapExactOutputSingle_oneForZero()"),
        # ("V4Router6.t.sol", "test_swapExactOut_revertsForAmountIn()"),
        # ("V4Router7.t.sol", "test_swapExactOut_1Hop_zeroForOne()"),
        # ("V4Router7.t.sol", "test_swapExactOut_1Hop_oneForZero()"),
        # ("V4Router7.t.sol", "test_swapExactOut_2Hops()"),
        # ("V4Router7.t.sol", "test_swapExactOut_3Hops()"),
        # ("V4Router8.t.sol", "test_nativeIn_swapExactOutputSingle_sweepExcessETH()"),
        # ("V4Router8.t.sol", "test_nativeOut_swapExactOutputSingle()"),
        # ("V4Router8.t.sol", "test_nativeIn_swapExactOut_1Hop_sweepExcessETH()"),
        # ("V4Router8.t.sol", "test_nativeOut_swapExactOut_1Hop()"),
        # ("V4Router9.t.sol", "test_nativeIn_swapExactOut_2Hops_sweepExcessETH()"),
        # ("V4Router9.t.sol", "test_swapExactInputSingle_zeroForOne_takeToRouter()"),
    ]

    @pytest.mark.parametrize("contract_name,call_method", TEST_FUNCTIONS)
    def test_swap_functions(self, contract_name, call_method, v4_router_test, faucet, accounts, web3_client):
        contract = v4_router_test[contract_name]
        print(f"Sender: {accounts[0].address}")
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        print(f"Balance: {web3_client.get_balance(sender_account)}")
        print(f"Balance V4T: {web3_client.get_balance(contract.address)}")

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)
        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1
