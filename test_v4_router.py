import pytest

from utils import EthAccounts, NeonChainWeb3Client, decode_function_signature


class TestV4Router:

    TEST_FUNCTIONS = [
        pytest.param(
            "V4Router.t.sol",
            "test_swapExactInputSingle_revertsForAmountOut()",
            marks=pytest.mark.xfail(reson="execution reverted"),
        ),
        ("V4Router.t.sol", "test_swapExactInputSingle_zeroForOne_takeToMsgSender()"),
        pytest.param(
            "V4Router.t.sol",
            "test_swapExactInputSingle_zeroForOne_takeToRecipient()",
            marks=pytest.mark.xfail(reson="'too many accounts: 65 > 64', 'no data'"),
        ),
        pytest.param(
            "V4Router.t.sol",
            "test_swapExactInputSingle_zeroForOne_takeAllToRouter()",
            marks=pytest.mark.xfail(reson="'too many accounts: 65 > 64', 'no data'"),
        ),
        ("V4Router2.t.sol", "test_swapExactInputSingle_oneForZero()"),
        pytest.param(
            "V4Router2.t.sol",
            "test_swapExactInput_revertsForAmountOut()",
            marks=pytest.mark.xfail(reson="'execution reverted', '0x'"),
        ),
        ("V4Router2.t.sol", "test_swapExactIn_1Hop_zeroForOne()"),
        pytest.param(
            "V4Router2.t.sol", "test_swapExactIn_2Hops()", marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'")
        ),
        ("V4Router3.t.sol", "test_swapExactIn_3Hops()"),
        ("V4Router3.t.sol", "test_swap_settleRouterBalance_swapOpenDelta()"),
        ("V4Router3.t.sol", "test_nativeIn_swapExactInputSingle()"),
        pytest.param(
            "V4Router4.t.sol",
            "test_nativeOut_swapExactInputSingle()",
            marks=pytest.mark.xfail(
                reson="execution reverted: output balance 0 after should be equal expected amount out 992054607780215625"
            ),
        ),
        ("V4Router4.t.sol", "test_nativeIn_swapExactIn_1Hop()"),
        pytest.param(
            "V4Router4.t.sol",
            "test_nativeOut_swapExactIn_1Hop()",
            marks=pytest.mark.xfail(reson="'too many accounts: 65 > 64', 'no data'"),
        ),
        pytest.param(
            "V4Router4.t.sol",
            "test_nativeIn_swapExactIn_2Hops()",
            marks=pytest.mark.xfail(reson="'too many accounts: 65 > 64', 'no data'"),
        ),
        pytest.param(
            "V4Router5.t.sol",
            "test_nativeOut_swapExactIn_2Hops()",
            marks=pytest.mark.xfail(
                reson="utput balance 0 after should be equal expected amount out 984211133872795298"
            ),
        ),
        ("V4Router5.t.sol", "test_swap_nativeIn_settleRouterBalance_swapOpenDelta()"),
        pytest.param(
            "V4Router6.t.sol",
            "test_swapExactOutputSingle_revertsForAmountIn()",
            marks=pytest.mark.xfail(reson="'execution reverted', '0x'"),
        ),
        ("V4Router6.t.sol", "test_swapExactOutputSingle_zeroForOne()"),
        ("V4Router6.t.sol", "test_swapExactOutputSingle_oneForZero()"),
        pytest.param(
            "V4Router6.t.sol",
            "test_swapExactOut_revertsForAmountIn()",
            marks=pytest.mark.xfail(reson="'execution reverted', '0x'"),
        ),
        pytest.param(
            "V4Router7.t.sol",
            "test_swapExactOut_1Hop_zeroForOne()",
            marks=pytest.mark.xfail(
                reson="'0x3351b2600000000000000000000000009dcced5ebf32f6dce66366e8e77faa4ca69c7260', '0x3351b2600000000000000000000000009dcced5ebf32f6dce66366e8e77faa4ca69c7260'"
            ),
        ),
        pytest.param(
            "V4Router7.t.sol",
            "test_swapExactOut_1Hop_oneForZero()",
            marks=pytest.mark.xfail(reson="0x486aa307', '0x486aa307'"),
        ),
        pytest.param(
            "V4Router7.t.sol", "test_swapExactOut_2Hops()", marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'")
        ),
        pytest.param(
            "V4Router7.t.sol", "test_swapExactOut_3Hops()", marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'")
        ),
        ("V4Router8.t.sol", "test_nativeIn_swapExactOutputSingle_sweepExcessETH()"),
        pytest.param(
            "V4Router8.t.sol",
            "test_nativeOut_swapExactOutputSingle()",
            marks=pytest.mark.xfail(
                reson="'execution reverted: output balance after 0 should be equal to amountOut 1000000000000000000'"
            ),
        ),
        ("V4Router8.t.sol", "test_nativeIn_swapExactOut_1Hop_sweepExcessETH()"),
        pytest.param(
            "V4Router8.t.sol",
            "test_nativeOut_swapExactOut_1Hop()",
            marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307"),
        ),
        ("V4Router9.t.sol", "test_nativeIn_swapExactOut_2Hops_sweepExcessETH()"),
        ("V4Router9.t.sol", "test_swapExactInputSingle_zeroForOne_takeToRouter()"),
    ]

    @pytest.mark.parametrize("contract_name, call_method", TEST_FUNCTIONS)
    def test_swap_functions(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        print(f"Sender: {sender_account}")
        print(f"Balance: {web3_client.get_balance(sender_account)}")
        print(f"Balance V4T: {web3_client.get_balance(contract.address)}")

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1
