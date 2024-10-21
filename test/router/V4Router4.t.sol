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

    function test_nativeOut_swapExactInputSingle() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        // native output means we need !zeroForOne
        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(nativeKey, false, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(nativeKey.currency1, nativeKey.currency0, amountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

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

    function test_nativeIn_swapExactIn_1Hop() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        tokenPath.push(nativeKey.currency1);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);
        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(CurrencyLibrary.ADDRESS_ZERO, nativeKey.currency1, amountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            "input balance before should be equal input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance after should be equal expected amount out"
        );
    }

    function test_nativeOut_swapExactIn_1Hop() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        tokenPath.push(nativeKey.currency1);
        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(nativeKey.currency1, CurrencyLibrary.ADDRESS_ZERO, amountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

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

    function test_nativeIn_swapExactIn_2Hops() public {
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 984211133872795298;

        // the initialized nativeKey is (native, currency0)
        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactInputParams memory params = _getExactInputParams(tokenPath, amountIn);

        plan = plan.add(Actions.SWAP_EXACT_IN, abi.encode(params));

        uint256 intermediateBalanceBefore = currency0.balanceOfSelf();

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(CurrencyLibrary.ADDRESS_ZERO, currency1, amountIn);

        // check intermediate token balances
        // assertEq(intermediateBalanceBefore, currency0.balanceOfSelf());
        require(
            intermediateBalanceBefore == currency0.balanceOfSelf(),
            "intermediate balance before should be equal currency0 balance of self"
        );

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, amountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == amountIn,
            "output balance after should be equal expected amount out"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, expectedAmountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == expectedAmountOut,
            "output balance after should be equal expected amount out"
        );
    }
}
