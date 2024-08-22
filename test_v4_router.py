import pytest

from utils import decode_function_signature


class TestV4Router:

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
        ],
    )
    @pytest.mark.contract_filename(name="V4Router.t.sol")
    def test_swap_functions(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
            ("V4Router2.t.sol", "test_swapExactInputSingle_oneForZero()"),
            pytest.param(
                "V4Router2.t.sol",
                "test_swapExactInput_revertsForAmountOut()",
                marks=pytest.mark.xfail(reson="'execution reverted', '0x'"),
            ),
            ("V4Router2.t.sol", "test_swapExactIn_1Hop_zeroForOne()"),
            pytest.param(
                "V4Router2.t.sol",
                "test_swapExactIn_2Hops()",
                marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'"),
            ),
        ],
    )
    @pytest.mark.contract_filename(name="V4Router2.t.sol")
    def test_swap_functions_2(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
        ],
    )
    @pytest.mark.contract_filename(name="V4Router3.t.sol")
    def test_swap_functions_3(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
        ],
    )
    @pytest.mark.contract_filename(name="V4Router4.t.sol")
    def test_swap_functions_4(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
            pytest.param(
                "V4Router5.t.sol",
                "test_nativeOut_swapExactIn_2Hops()",
                marks=pytest.mark.xfail(
                    reson="utput balance 0 after should be equal expected amount out 984211133872795298"
                ),
            ),
            ("V4Router5.t.sol", "test_swap_nativeIn_settleRouterBalance_swapOpenDelta()"),
        ],
    )
    @pytest.mark.contract_filename(name="V4Router5.t.sol")
    def test_swap_functions_5(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
        ],
    )
    @pytest.mark.contract_filename(name="V4Router6.t.sol")
    def test_swap_functions_6(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
                "V4Router7.t.sol",
                "test_swapExactOut_2Hops()",
                marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'"),
            ),
            pytest.param(
                "V4Router7.t.sol",
                "test_swapExactOut_3Hops()",
                marks=pytest.mark.xfail(reson="'0x486aa307', '0x486aa307'"),
            ),
        ],
    )
    @pytest.mark.contract_filename(name="V4Router7.t.sol")
    def test_swap_functions_7(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
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
        ],
    )
    @pytest.mark.contract_filename(name="V4Router8.t.sol")
    def test_swap_functions_8(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
            ("V4Router9.t.sol", "test_nativeIn_swapExactOut_2Hops_sweepExcessETH()"),
        ],
    )
    @pytest.mark.contract_filename(name="V4Router9.t.sol")
    def test_swap_functions_9(self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 300)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1

    @pytest.mark.parametrize(
        "contract_name, call_method",
        [
            ("V4Router9.t.sol", "test_swapExactInputSingle_zeroForOne_takeToRouter()"),
        ],
    )
    @pytest.mark.contract_filename(name="V4Router9.t.sol")
    def test_swap_functions_9_without_balance(
        self, contract_name, call_method, accounts, v4_router_test, web3_client, faucet
    ):
        contract = v4_router_test[contract_name]
        print(f"V4RouterTest: {contract.address}")

        sender_account = accounts[0]
        faucet.request_neon(contract.address, 200)

        tx = web3_client.make_raw_tx(sender_account)
        intruction_tx = contract.functions.setUp().build_transaction(tx)
        receipt = web3_client.send_transaction(sender_account, intruction_tx)

        call_data = decode_function_signature(call_method)

        tx = web3_client.make_raw_tx(sender_account, to=contract.address, data=call_data, estimate_gas=True)
        receipt = web3_client.send_transaction(sender_account, tx)
        assert receipt["status"] == 1
