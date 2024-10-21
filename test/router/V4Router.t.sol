// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Currency, CurrencyLibrary} from "../../lib/v4-core/src/types/Currency.sol";
import {IV4Router} from "../../src/interfaces/IV4Router.sol";
import {RoutingTestHelpers} from "../shared/RoutingTestHelpers.sol";
import {Plan, Planner} from "../shared/Planner.sol";
import {Actions} from "../../src/libraries/Actions.sol";
import {ActionConstants} from "../../src/libraries/ActionConstants.sol";
import {MockV4Router} from "../mocks/MockV4Router.sol";
import {PositionManager} from "../../src/PositionManager.sol";

contract V4RouterTest is RoutingTestHelpers {
    using CurrencyLibrary for Currency;
    using Planner for Plan;

    address alice;
    address payable ra;
    address payable ma;
    address payable pos_manager;

    constructor(address payable routerAddr, address payable managerAddr, address payable positionManagerAddr) {
        ra = routerAddr;
        ma = managerAddr;
        alice = msg.sender;
        pos_manager = positionManagerAddr;
    }

    function setUp() public {
        setupRouterCurrenciesAndPoolsWithLiquidity(ra, ma, pos_manager);
        plan = Planner.init();
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 -> ERC20 EXACT INPUT
    //////////////////////////////////////////////////////////////*/

    function test_swapExactInputSingle_revertsForAmountOut() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        // min amount out of 1 higher than the actual amount out
        IV4Router.ExactInputSingleParams memory params = IV4Router.ExactInputSingleParams(
            key0, true, uint128(amountIn), uint128(expectedAmountOut + 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));
        bytes memory data = plan.finalizeSwap(key0.currency0, key0.currency1, ActionConstants.MSG_SENDER);

        vm.expectRevert(
            abi.encodeWithSelector(IV4Router.V4TooLittleReceived.selector, expectedAmountOut + 1, expectedAmountOut)
        );
        router.executeActions(data);
        // vm.expectRevert(IV4Router.V4TooLittleReceived.selector);
        // router.executeActions(data);
    }

    function uintToString(uint256 _value) public pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }
        return string(buffer);
    }

    function test_swapExactInputSingle_zeroForOne_takeToMsgSender() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, true, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));
        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency0, key0.currency1, amountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance of router is not 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency0 balance of router is not 0");
        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            string.concat(uintToString(inputBalanceBefore - inputBalanceAfter), " != ", uintToString(amountIn))
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
    }

    function test_swapExactInputSingle_zeroForOne_takeToRecipient() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, true, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));

        uint256 aliceOutputBalanceBefore = key0.currency1.balanceOf(alice);

        // swap with alice as the take recipient
        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency0, key0.currency1, amountIn, alice);

        uint256 aliceOutputBalanceAfter = key0.currency1.balanceOf(alice);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance of router is not 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance of router is not 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            string.concat(uintToString(inputBalanceBefore - inputBalanceAfter), " != ", uintToString(amountIn))
        );
        // // this contract's output balance has not changed because funds went to alice
        // assertEq(outputBalanceAfter, outputBalanceBefore);
        require(
            outputBalanceAfter == outputBalanceBefore,
            string.concat(uintToString(outputBalanceAfter), " != ", uintToString(outputBalanceBefore))
        );
        // assertEq(aliceOutputBalanceAfter - aliceOutputBalanceBefore, expectedAmountOut);
        require(
            aliceOutputBalanceAfter - aliceOutputBalanceBefore == expectedAmountOut,
            string.concat(
                uintToString(aliceOutputBalanceAfter - aliceOutputBalanceBefore),
                " != ",
                uintToString(expectedAmountOut)
            )
        );
    }

    // This is not a real use-case in isolation, but will be used in the UniversalRouter if a v4
    // swap is before another swap on v2/v3
    function test_swapExactInputSingle_zeroForOne_takeAllToRouter() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, true, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));

        // the router holds no funds before
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance of router is not 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require((currency1.balanceOf(address(router))) == 0, "currency1 balance of router is not 0");

        // swap with the router as the take recipient
        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency0, key0.currency1, amountIn, ActionConstants.ADDRESS_THIS);

        // the output tokens have been left in the router
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance of router is not 0");
        // assertEq(currency1.balanceOf(address(router)), expectedAmountOut);
        require(
            currency1.balanceOf(address(router)) == expectedAmountOut,
            "currency1 balance of router is not expectedAmountOut"
        );

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            string.concat(uintToString(inputBalanceBefore - inputBalanceAfter), " != ", uintToString(amountIn))
        );
        // this contract's output balance has not changed because funds went to the router
        // assertEq(outputBalanceAfter, outputBalanceBefore);
        require(
            outputBalanceAfter == outputBalanceBefore,
            string.concat(uintToString(outputBalanceAfter), " != ", uintToString(outputBalanceBefore))
        );
    }
}
