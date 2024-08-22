// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {PoolModifyLiquidityTest} from "../../lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {MockV4Router} from "../mocks/MockV4Router.sol";
import {Plan, Planner} from "../shared/Planner.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IHooks} from "../../lib/v4-core/src/interfaces/IHooks.sol";
import {PathKey} from "../../src/libraries/PathKey.sol";
import {Actions} from "../../src/libraries/Actions.sol";
import {Currency, CurrencyLibrary} from "../../lib/v4-core/src/types/Currency.sol";
import {IPoolManager} from "../../lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "../../lib/v4-core/src/types/PoolKey.sol";
import {LiquidityOperations} from "./LiquidityOperations.sol";
import {IV4Router} from "../../src/interfaces/IV4Router.sol";
import {ActionConstants} from "../../src/libraries/ActionConstants.sol";
import {Constants} from "../../lib/v4-core/test/utils/Constants.sol";
import {PoolManager} from "../../lib/v4-core/src/PoolManager.sol";
import {PoolId} from "../../lib/v4-core/src/types/PoolId.sol";
import {SortTokens} from "../../lib/v4-core/test/utils/SortTokens.sol";
import {LPFeeLibrary} from "../../lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "../../lib/v4-core/src/libraries/StateLibrary.sol";
import {BalanceDelta} from "../../lib/v4-core/src/types/BalanceDelta.sol";
import {PoolSwapTest} from "../../lib/v4-core/src/test/PoolSwapTest.sol";
import {LiquidityAmounts} from "../../lib/v4-core/test/utils/LiquidityAmounts.sol";

/// @notice A shared test contract that wraps the v4-core deployers contract and exposes basic helpers for swapping with the router.
contract RoutingTestHelpers is Test {
    using Planner for Plan;
    using LPFeeLibrary for uint24;
    using StateLibrary for IPoolManager;

    // Helpful test constants
    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;
    uint160 constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;
    uint160 constant SQRT_PRICE_1_2 = Constants.SQRT_PRICE_1_2;
    uint160 constant SQRT_PRICE_2_1 = Constants.SQRT_PRICE_2_1;
    uint160 constant SQRT_PRICE_1_4 = Constants.SQRT_PRICE_1_4;
    uint160 constant SQRT_PRICE_4_1 = Constants.SQRT_PRICE_4_1;

    uint256 MAX_SETTLE_AMOUNT = type(uint256).max;
    uint256 MIN_TAKE_AMOUNT = 0;

    IPoolManager.ModifyLiquidityParams public LIQUIDITY_PARAMS =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0});
    IPoolManager.ModifyLiquidityParams public REMOVE_LIQUIDITY_PARAMS =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: 0});
    IPoolManager.SwapParams public SWAP_PARAMS =
        IPoolManager.SwapParams({zeroForOne: true, amountSpecified: -100, sqrtPriceLimitX96: SQRT_PRICE_1_2});

    PoolModifyLiquidityTest positionManager;
    PoolModifyLiquidityTest modifyLiquidityRouter;
    PoolSwapTest swapRouter;
    MockV4Router router;
    IPoolManager manager;

    // nativeKey is already defined in Deployers.sol
    PoolKey key;
    PoolKey nativeKey;
    PoolKey uninitializedKey;
    PoolKey uninitializedNativeKey;

    PoolKey key0;
    PoolKey key1;
    PoolKey key2;

    // currency0 and currency1 are defined in Deployers.sol
    Currency internal currency0;
    Currency internal currency1;
    Currency currency2;
    Currency currency3;

    Currency[] tokenPath;
    Plan plan;

    function setupRouterCurrenciesAndPoolsWithLiquidity(
        address payable routerAddr,
        address payable managerAddr,
        address payable posManagerAddr
    ) public {
        router = MockV4Router(routerAddr);
        manager = IPoolManager(managerAddr);
        positionManager = PoolModifyLiquidityTest(posManagerAddr);

        MockERC20[] memory tokens = deployTokensMintAndApprove(4);

        currency0 = Currency.wrap(address(tokens[0]));
        currency1 = Currency.wrap(address(tokens[1]));
        currency2 = Currency.wrap(address(tokens[2]));
        currency3 = Currency.wrap(address(tokens[3]));

        nativeKey = createNativePoolWithLiquidity(currency0, address(0));
        key0 = createPoolWithLiquidity(currency0, currency1, address(0));
        key1 = createPoolWithLiquidity(currency1, currency2, address(0));
        key2 = createPoolWithLiquidity(currency2, currency3, address(0));
    }

    function deployTokens(uint8 count, uint256 totalSupply) internal returns (MockERC20[] memory tokens) {
        tokens = new MockERC20[](count);
        for (uint8 i = 0; i < count; i++) {
            tokens[i] = new MockERC20("TEST", "TEST", 18);
            tokens[i].mint(address(this), totalSupply);
        }
    }

    function deployTokensMintAndApprove(uint8 count) internal returns (MockERC20[] memory) {
        MockERC20[] memory tokens = deployTokens(count, 2 ** 128);
        for (uint256 i = 0; i < count; i++) {
            tokens[i].approve(address(router), type(uint256).max);
        }
        return tokens;
    }

    function createPoolWithLiquidity(Currency currencyA, Currency currencyB, address hookAddr)
        internal
        returns (PoolKey memory _key)
    {
        if (Currency.unwrap(currencyA) > Currency.unwrap(currencyB)) (currencyA, currencyB) = (currencyB, currencyA);
        _key = PoolKey(currencyA, currencyB, 3000, 60, IHooks(hookAddr));

        manager.initialize(_key, SQRT_PRICE_1_1, ZERO_BYTES);
        MockERC20(Currency.unwrap(currencyA)).approve(address(positionManager), type(uint256).max);
        MockERC20(Currency.unwrap(currencyB)).approve(address(positionManager), type(uint256).max);
        positionManager.modifyLiquidity(_key, IPoolManager.ModifyLiquidityParams(-887220, 887220, 200 ether, 0), "0x");
    }

    function createNativePoolWithLiquidity(Currency currency, address hookAddr)
        internal
        returns (PoolKey memory _key)
    {
        _key = PoolKey(CurrencyLibrary.ADDRESS_ZERO, currency, 3000, 60, IHooks(hookAddr));

        manager.initialize(_key, SQRT_PRICE_1_1, ZERO_BYTES);
        MockERC20(Currency.unwrap(currency)).approve(address(positionManager), type(uint256).max);
        positionManager.modifyLiquidity{value: 200 ether}(
            _key, IPoolManager.ModifyLiquidityParams(-887220, 887220, 200 ether, 0), "0x"
        );
    }

    function _finalizeAndExecuteSwap(
        Currency inputCurrency,
        Currency outputCurrency,
        uint256 amountIn,
        address takeRecipient
    )
        internal
        returns (
            uint256 inputBalanceBefore,
            uint256 outputBalanceBefore,
            uint256 inputBalanceAfter,
            uint256 outputBalanceAfter
        )
    {
        inputBalanceBefore = inputCurrency.balanceOfSelf();
        outputBalanceBefore = outputCurrency.balanceOfSelf();

        bytes memory data = plan.finalizeSwap(inputCurrency, outputCurrency, takeRecipient);

        uint256 value = (inputCurrency.isAddressZero()) ? amountIn : 0;

        // otherwise just execute as normal
        router.executeActions{value: value}(data);

        inputBalanceAfter = inputCurrency.balanceOfSelf();
        outputBalanceAfter = outputCurrency.balanceOfSelf();
    }

    function _finalizeAndExecuteSwap(Currency inputCurrency, Currency outputCurrency, uint256 amountIn)
        internal
        returns (
            uint256 inputBalanceBefore,
            uint256 outputBalanceBefore,
            uint256 inputBalanceAfter,
            uint256 outputBalanceAfter
        )
    {
        return _finalizeAndExecuteSwap(inputCurrency, outputCurrency, amountIn, ActionConstants.MSG_SENDER);
    }

    function _finalizeAndExecuteNativeInputExactOutputSwap(
        Currency inputCurrency,
        Currency outputCurrency,
        uint256 expectedAmountIn
    )
        internal
        returns (
            uint256 inputBalanceBefore,
            uint256 outputBalanceBefore,
            uint256 inputBalanceAfter,
            uint256 outputBalanceAfter
        )
    {
        inputBalanceBefore = inputCurrency.balanceOfSelf();
        outputBalanceBefore = outputCurrency.balanceOfSelf();

        bytes memory data = plan.finalizeSwap(inputCurrency, outputCurrency, ActionConstants.MSG_SENDER);

        // send too much ETH to mimic slippage
        // uint256 value = expectedAmountIn + 0.1 ether;
        // router.executeActionsAndSweepExcessETH{value: value}(data);
        router.executeActions{value: expectedAmountIn}(data);

        inputBalanceAfter = inputCurrency.balanceOfSelf();
        outputBalanceAfter = outputCurrency.balanceOfSelf();
    }

    function _getExactInputParams(Currency[] memory _tokenPath, uint256 amountIn)
        internal
        pure
        returns (IV4Router.ExactInputParams memory params)
    {
        PathKey[] memory path = new PathKey[](_tokenPath.length - 1);
        for (uint256 i = 0; i < _tokenPath.length - 1; i++) {
            path[i] = PathKey(_tokenPath[i + 1], 3000, 60, IHooks(address(0)), bytes(""));
        }

        params.currencyIn = _tokenPath[0];
        params.path = path;
        params.amountIn = uint128(amountIn);
        params.amountOutMinimum = 0;
    }

    function _getExactOutputParams(Currency[] memory _tokenPath, uint256 amountOut)
        internal
        pure
        returns (IV4Router.ExactOutputParams memory params)
    {
        PathKey[] memory path = new PathKey[](_tokenPath.length - 1);
        for (uint256 i = _tokenPath.length - 1; i > 0; i--) {
            path[i - 1] = PathKey(_tokenPath[i - 1], 3000, 60, IHooks(address(0)), bytes(""));
        }

        params.currencyOut = _tokenPath[_tokenPath.length - 1];
        params.path = path;
        params.amountOut = uint128(amountOut);
        params.amountInMaximum = type(uint128).max;
    }
}
