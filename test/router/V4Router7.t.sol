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

    function test_swapExactOut_1Hop_zeroForOne() public {
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency0, key0.currency1, expectedAmountIn);

        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance should be equal to expectedAmountIn"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(outputBalanceAfter - outputBalanceBefore == amountOut, "output balance should be equal to amountOut");
    }

    function test_swapExactOut_1Hop_oneForZero() public {
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        tokenPath.push(currency1);
        tokenPath.push(currency0);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency1, currency0, expectedAmountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance should be equal to expectedAmountIn"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(outputBalanceAfter - outputBalanceBefore == amountOut, "output balance should be equal to amountOut");
    }

    function test_swapExactOut_2Hops() public {
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1016204441757464409;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        tokenPath.push(currency2);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        uint256 intermediateBalanceBefore = currency1.balanceOfSelf();

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency0, currency2, expectedAmountIn);

        // assertEq(intermediateBalanceBefore, currency1.balanceOfSelf());
        require(intermediateBalanceBefore == currency1.balanceOfSelf(), "intermediate balance should be equal");
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency2.balanceOf(address(router)), 0);
        require(currency2.balanceOf(address(router)) == 0, "currency2 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance should be equal to expectedAmountIn"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(outputBalanceAfter - outputBalanceBefore == amountOut, "output balance should be equal to amountOut");
    }

    function test_swapExactOut_3Hops() public {
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1024467570922834110;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        tokenPath.push(currency2);
        tokenPath.push(currency3);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency0, currency3, expectedAmountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency2.balanceOf(address(router)), 0);
        require(currency2.balanceOf(address(router)) == 0, "currency2 balance should be 0");
        // assertEq(currency3.balanceOf(address(router)), 0);
        require(currency3.balanceOf(address(router)) == 0, "currency3 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance should be equal to expectedAmountIn"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(outputBalanceAfter - outputBalanceBefore == amountOut, "output balance should be equal to amountOut");
    }
}
