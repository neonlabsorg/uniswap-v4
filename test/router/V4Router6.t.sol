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

    //     /*//////////////////////////////////////////////////////////////å
    //                         ERC20 -> ERC20 EXACT OUTPUT
    //     //////////////////////////////////////////////////////////////*/

    function test_swapExactOutputSingle_revertsForAmountIn() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        IV4Router.ExactOutputSingleParams memory params = IV4Router.ExactOutputSingleParams(
            key0, true, uint128(amountOut), uint128(expectedAmountIn - 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_OUT_SINGLE, abi.encode(params));
        bytes memory data = plan.finalizeSwap(key0.currency0, key0.currency1, ActionConstants.MSG_SENDER);

        vm.expectRevert(IV4Router.V4TooMuchRequested.selector);
        router.executeActions(data);
    }

    function test_swapExactOutputSingle_zeroForOne() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        IV4Router.ExactOutputSingleParams memory params = IV4Router.ExactOutputSingleParams(
            key0, true, uint128(amountOut), uint128(expectedAmountIn + 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_OUT_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency0, key0.currency1, expectedAmountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance before should be equal to input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut, "output balance after should be equal to amount out"
        );
    }

    function test_swapExactOutputSingle_oneForZero() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        IV4Router.ExactOutputSingleParams memory params = IV4Router.ExactOutputSingleParams(
            key0, false, uint128(amountOut), uint128(expectedAmountIn + 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_OUT_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency1, key0.currency0, expectedAmountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance before should be equal to input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut, "output balance after should be equal to amount out"
        );
    }

    function test_swapExactOut_revertsForAmountIn() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);
        params.amountInMaximum = uint128(expectedAmountIn - 1);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));
        bytes memory data = plan.finalizeSwap(key0.currency0, key0.currency1, ActionConstants.MSG_SENDER);

        vm.expectRevert(
            abi.encodeWithSelector(IV4Router.V4TooMuchRequested.selector, expectedAmountIn - 1, expectedAmountIn)
        );
        router.executeActions(data);
    }
}
