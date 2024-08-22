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

    function test_nativeOut_swapExactIn_2Hops() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 984211133872795298;

        // the initialized nativeKey is (native, currency0)
        tokenPath.push(currency1);
        tokenPath.push(currency0);
        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        uint256 intermediateBalanceBefore = currency0.balanceOfSelf();

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(currency1, CurrencyLibrary.ADDRESS_ZERO, amountIn);

        // check intermediate token balances
        // assertEq(intermediateBalanceBefore, currency0.balanceOfSelf());
        require(intermediateBalanceBefore == currency0.balanceOfSelf(), "intermediate balance should be equal");
        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            "input balance before should be equal input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            string.concat(
                "output balance ",
                uintToString(outputBalanceAfter - outputBalanceBefore),
                " after should be equal expected amount out ",
                uintToString(expectedAmountOut)
            )
        );
    }

    function test_swap_nativeIn_settleRouterBalance_swapOpenDelta() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        nativeKey.currency0.transfer(address(router), amountIn);

        // amount in of 0 to show it should use the open delta
        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(nativeKey, true, ActionConstants.OPEN_DELTA, 0, 0, bytes(""));

        plan = plan.add(Actions.SETTLE, abi.encode(nativeKey.currency0, ActionConstants.CONTRACT_BALANCE, false));
        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));
        plan = plan.add(Actions.TAKE_ALL, abi.encode(nativeKey.currency1, MIN_TAKE_AMOUNT));

        bytes memory data = plan.encode();

        uint256 callerInputBefore = nativeKey.currency0.balanceOfSelf();
        uint256 routerInputBefore = nativeKey.currency0.balanceOf(address(router));
        uint256 callerOutputBefore = nativeKey.currency1.balanceOfSelf();
        router.executeActions(data);

        uint256 callerInputAfter = nativeKey.currency0.balanceOfSelf();
        uint256 routerInputAfter = nativeKey.currency0.balanceOf(address(router));
        uint256 callerOutputAfter = nativeKey.currency1.balanceOfSelf();

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
}
