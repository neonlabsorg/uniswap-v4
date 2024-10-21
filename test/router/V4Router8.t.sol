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

    //     /*//////////////////////////////////////////////////////////////
    //                 ETH -> ERC20 and ERC20 -> ETH EXACT OUTPUT
    //     //////////////////////////////////////////////////////////////*/

    function test_nativeIn_swapExactOutputSingle_sweepExcessETH() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        IV4Router.ExactOutputSingleParams memory params = IV4Router.ExactOutputSingleParams(
            nativeKey, true, uint128(amountOut), uint128(expectedAmountIn + 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_OUT_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteNativeInputExactOutputSwap(nativeKey.currency0, nativeKey.currency1, expectedAmountIn);

        // // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(
            nativeKey.currency0.balanceOf(address(router)) == 0,
            string.concat(
                "currency0 balance should be 0", " got ", uintToString(nativeKey.currency0.balanceOf(address(router)))
            )
        );
        // // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");

        // // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            string.concat(
                "input balance ",
                uintToString(inputBalanceBefore - inputBalanceAfter),
                " should be equal to expectedAmountIn ",
                uintToString(expectedAmountIn)
            )
        );
        // // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(outputBalanceAfter - outputBalanceBefore == amountOut, "output balance should be equal to amountOut");
    }

    function test_nativeOut_swapExactOutputSingle() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        IV4Router.ExactOutputSingleParams memory params = IV4Router.ExactOutputSingleParams(
            nativeKey, false, uint128(amountOut), uint128(expectedAmountIn + 1), 0, bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_OUT_SINGLE, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(nativeKey.currency1, nativeKey.currency0, expectedAmountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance before should be equal input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut,
            string.concat(
                "output balance after ",
                uintToString(outputBalanceAfter - outputBalanceBefore),
                " should be equal to amountOut ",
                uintToString(amountOut)
            )
        );
    }

    function test_nativeIn_swapExactOut_1Hop_sweepExcessETH() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        tokenPath.push(nativeKey.currency1);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteNativeInputExactOutputSwap(
            CurrencyLibrary.ADDRESS_ZERO, nativeKey.currency1, expectedAmountIn
        );

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance before should be equal input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut, "output balance after should be equal to amountOut"
        );
    }

    function test_nativeOut_swapExactOut_1Hop() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1008049273448486163;

        tokenPath.push(nativeKey.currency1);
        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteSwap(nativeKey.currency1, CurrencyLibrary.ADDRESS_ZERO, expectedAmountIn);

        // assertEq(nativeKey.currency0.balanceOf(address(router)), 0);
        require(nativeKey.currency0.balanceOf(address(router)) == 0, "router balance should be equal 0");
        // assertEq(nativeKey.currency1.balanceOf(address(router)), 0);
        require(nativeKey.currency1.balanceOf(address(router)) == 0, "router balance should be equal 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            "input balance before should be equal input balance after"
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut,
            string.concat(
                "output balance after ",
                uintToString(outputBalanceAfter - outputBalanceBefore),
                " should be equal expected amount out ",
                uintToString(amountOut)
            )
        );
    }
}
