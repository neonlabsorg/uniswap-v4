// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Currency, CurrencyLibrary} from "../../lib/v4-core/src/types/Currency.sol";
import {IV4Router} from "../../src/interfaces/IV4Router.sol";
import {RoutingTestHelpers} from "../shared/RoutingTestHelpers.sol";
import {Plan, Planner} from "../shared/Planner.sol";
import {Actions} from "../../src/libraries/Actions.sol";
import {ActionConstants} from "../../src/libraries/ActionConstants.sol";
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

    function test_nativeIn_swapExactOut_2Hops_sweepExcessETH() public {
        plan = Planner.init();
        uint256 amountOut = 1 ether;
        uint256 expectedAmountIn = 1016204441757464409;

        // the initialized nativeKey is (native, currency0)
        tokenPath.push(CurrencyLibrary.ADDRESS_ZERO);
        tokenPath.push(currency0);
        tokenPath.push(currency1);
        IV4Router.ExactOutputParams memory params = _getExactOutputParams(tokenPath, amountOut);

        uint256 intermediateBalanceBefore = currency0.balanceOfSelf();

        plan = plan.add(Actions.SWAP_EXACT_OUT, abi.encode(params));

        (uint256 inputBalanceBefore, uint256 outputBalanceBefore, uint256 inputBalanceAfter, uint256 outputBalanceAfter)
        = _finalizeAndExecuteNativeInputExactOutputSwap(CurrencyLibrary.ADDRESS_ZERO, currency1, expectedAmountIn);

        // assertEq(intermediateBalanceBefore, currency0.balanceOfSelf());
        require(
            intermediateBalanceBefore == currency0.balanceOfSelf(),
            string.concat(
                "intermediateBalanceBefore != currency0.balanceOfSelf(), got ", uintToString(currency0.balanceOfSelf())
            )
        );
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance should be 0");
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(currency0.balanceOf(address(router)) == 0, "currency0 balance should be 0");
        // assertEq(CurrencyLibrary.ADDRESS_ZERO.balanceOf(address(router)), 0);
        require(CurrencyLibrary.ADDRESS_ZERO.balanceOf(address(router)) == 0, "router balance should be 0");

        // assertEq(inputBalanceBefore - inputBalanceAfter, expectedAmountIn);
        require(
            inputBalanceBefore - inputBalanceAfter == expectedAmountIn,
            string.concat(
                "inputBalanceBefore - inputBalanceAfter != expectedAmountIn, got ",
                uintToString(inputBalanceBefore - inputBalanceAfter)
            )
        );
        // assertEq(outputBalanceAfter - outputBalanceBefore, amountOut);
        require(
            outputBalanceAfter - outputBalanceBefore == amountOut,
            string.concat(
                "outputBalanceAfter - outputBalanceBefore != amountOut, got ",
                uintToString(outputBalanceAfter - outputBalanceBefore)
            )
        );
    }

    // This is not a real use-case in isolation, but will be used in the UniversalRouter if a v4
    // swap is before another swap on v2/v3
    function test_swapExactInputSingle_zeroForOne_takeToRouter() public {
        plan = Planner.init();
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 992054607780215625;

        IV4Router.ExactInputSingleParams memory params =
            IV4Router.ExactInputSingleParams(key0, true, uint128(amountIn), 0, 0, bytes(""));

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params));
        plan = plan.add(Actions.SETTLE_ALL, abi.encode(key0.currency0, expectedAmountOut * 12 / 10));
        // take the entire open delta to the router's address
        plan =
            plan.add(Actions.TAKE, abi.encode(key0.currency1, ActionConstants.ADDRESS_THIS, ActionConstants.OPEN_DELTA));
        bytes memory data = plan.encode();

        // the router holds no funds before
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(
            currency0.balanceOf(address(router)) == 0,
            string.concat(
                "before currency0 balance of router is not 0, got ", uintToString(currency0.balanceOf(address(router)))
            )
        );
        // assertEq(currency1.balanceOf(address(router)), 0);
        require(currency1.balanceOf(address(router)) == 0, "currency1 balance of router is not 0");
        uint256 inputBalanceBefore = key0.currency0.balanceOfSelf();
        uint256 outputBalanceBefore = key0.currency1.balanceOfSelf();

        router.executeActions(data);

        // the output tokens have been left in the router
        // assertEq(currency0.balanceOf(address(router)), 0);
        require(
            currency0.balanceOf(address(router)) == 0,
            string.concat(
                "output currency0 balance of router is not 0, got ", uintToString(currency0.balanceOf(address(router)))
            )
        );
        // assertEq(currency1.balanceOf(address(router)), expectedAmountOut);
        require(
            currency1.balanceOf(address(router)) == expectedAmountOut,
            "currency1 balance of router is not expectedAmountOut"
        );
        uint256 inputBalanceAfter = key0.currency0.balanceOfSelf();
        uint256 outputBalanceAfter = key0.currency1.balanceOfSelf();

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
