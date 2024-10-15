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

    function test_swapExactIn_3Hops() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 976467664490096191;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        tokenPath.push(currency2);
        tokenPath.push(currency3);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency0, currency3, amountIn);

        // check intermediate tokens werent left in the router
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency2.balanceOf(address(router)), 0);
        require(currency2.balanceOf(address(router)) == 0, "currency2 balance should be 0");
        // assertEq(currency3.balanceOf(address(router)), 0);
        require(currency3.balanceOf(address(router)) == 0, "currency3 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(inputBalanceBefore - inputBalanceAfter == amountIn, "input balance should be equal to amountIn");
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance should be equal to expectedAmountOut"
        );
    }

    function test_swap_settleRouterBalance_swapOpenDelta() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        key0.currency0.transfer(address(router), amountIn);

        // amount in of 0 to show it should use the open delta
        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, true, ActionConstants.OPEN_DELTA, 0, 0, bytes(""));

        plan = plan.add(Actions.SETTLE, abi.encode(key0.currency0, ActionConstants.CONTRACT_BALANCE, false));
        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));
        plan = plan.add(Actions.TAKE_ALL, abi.encode(key0.currency1, MIN_TAKE_AMOUNT));

        bytes memory data = plan.encode();

        uint256 callerInputBefore = key0.currency0.balanceOfSelf();
        uint256 routerInputBefore = key0.currency0.balanceOf(address(router));
        uint256 callerOutputBefore = key0.currency1.balanceOfSelf();
        router.executeActions(data);

        uint256 callerInputAfter = key0.currency0.balanceOfSelf();
        uint256 routerInputAfter = key0.currency0.balanceOf(address(router));
        uint256 callerOutputAfter = key0.currency1.balanceOfSelf();

        // caller didnt pay, router paid, caller received the output
        // assertEq(callerInputBefore, callerInputAfter);
        require(callerInputBefore == callerInputAfter, "caller input before should be equal to caller input after");
        // assertEq(routerInputBefore - amountIn, routerInputAfter);
        require(
            routerInputBefore - amountIn == routerInputAfter,
            "router input before should be equal to router input after"
        );
        // assertEq(callerOutputBefore + expectedAmountOut, callerOutputAfter);
        require(
            callerOutputBefore + expectedAmountOut == callerOutputAfter,
            "caller output before should be equal to caller output after"
        );
    }

    function test_nativeIn_swapExactInputSingle() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(nativeKey, true, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(nativeKey.currency0, nativeKey.currency1, amountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance after should be equal expected amount out"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance after should be equal expected amount out"
        );
    }
}
