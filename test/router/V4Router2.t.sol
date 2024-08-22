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
import {IHooks} from "../../lib/v4-core/src/interfaces/IHooks.sol";

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

    function test_swapExactInputSingle_oneForZero() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, false, uint128(amountIn), 0, 0, bytes(""));
        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(key0.currency1, key0.currency0, amountIn);

        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        require(inputBalanceBefore - inputBalanceAfter == amountIn, "input balance should be equal to amountIn");
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance should be equal to expectedAmountOut"
        );
    }

    function test_swapExactInput_revertsForAmountOut() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);
        params.amountOutMinimum = uint128(expectedAmountOut + 1);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));
        bytes memory data = plan.finalizeSwap(key0.currency0, key0.currency1, ActionConstants.MSG_SENDER);

        vm.expectRevert(
            abi.encodeWithSelector(IV4Router.V4TooLittleReceived.selector, 992054607780215625 + 1, 992054607780215625)
        );
        router.executeActions(data);
    }

    function test_swapExactIn_1Hop_zeroForOne() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);
        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency0, currency1, amountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(inputBalanceBefore - inputBalanceAfter == amountIn, "input balance should be equal to amountIn");
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance should be equal to expectedAmountOut"
        );
    }

    function test_swapExactIn_1Hop_oneForZero() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        tokenPath.push(currency1);
        tokenPath.push(currency0);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency1, currency0, amountIn);

        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(inputBalanceBefore - inputBalanceAfter == amountIn, "input balance should be equal to amountIn");
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance should be equal to expectedAmountOut"
        );
    }

    function test_swapExactIn_2Hops() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 984211133872795298;

        tokenPath.push(currency0);
        tokenPath.push(currency1);
        tokenPath.push(currency2);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        uint256 intermediateBalanceBefore = currency1.balanceOfSelf();

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency0, currency2, amountIn);

        // check intermediate token balances
        // assertEq(intermediateBalanceBefore, currency1.balanceOfSelf());
        require(
            intermediateBalanceBefore == currency1.balanceOfSelf(),
            "intermediate balance should be equal to currency1 balance"
        );
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency2.balanceOf(address(router)), 0);
        require(currency2.balanceOf(address(router)) == 0, "currency2 balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(inputBalanceBefore - inputBalanceAfter == amountIn, "input balance should be equal to amountIn");
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance should be equal to expectedAmountOut"
        );
    }
}
