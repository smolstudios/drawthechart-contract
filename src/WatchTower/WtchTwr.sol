// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;
pragma abicoder v2;

import "@WtchTwrDefi/TickMath.sol";
import "@WtchTwrDefi/FullMath.sol";
import {IERC20TokenV06} from "@WtchTwrDefi/IERC20TokenV06.sol";
import {
    IUniswapV3Pool,
    IUniswapV3Factory,
    FixedPoint96,
    SafeMath,
    EvenOdd,
    PackUnpackUint32
} from "./ObservationUtils.sol";

struct ObservationData {
    uint160 price;
    uint32 timestamp;
}

/// @title A contract that gets observation data from Uniswap V3 and returns the average price for a given time period
contract WtchTwr {
    using SafeMath for uint256;
    using EvenOdd for uint256;

    //Base uniswap v3 factory contract address from https://docs.uniswap.org/contracts/v3/reference/deployments
    //https://basescan.org/address/0x33128a8fc17869897dce68ed026d694621f6fdfd#code
    IUniswapV3Factory public v3Factory;

    modifier isNotZeroAddress(address pool) {
        require(pool != address(0), "No existing Uniswap V3 Pool");
        _;
    }

    modifier isValidUniswapV3Pool(IUniswapV3Pool pool) {
        require(
            address(pool.factory()) == address(v3Factory),
            "Pool not created by the canonical v3 factory @ 0x33128a8fc17869897dce68ed026d694621f6fdfd"
        );
        _;
    }

    /// @notice Get the pool address for the given tokens and fee
    /// @param tokenA The first token
    /// @param tokenB The second token
    /// @param fee The fee
    /// @return The pool address
    function getPoolAddress(address tokenA, address tokenB, uint24 fee) public view returns (address) {
        return v3Factory.getPool(tokenA, tokenB, fee);
    }

    /// @notice Sets the Uniswap V3 factory address
    /// @param uniswapV3Factory Address of the Uniswap V3 factory
    /// @return Address of the set Uniswap V3 factory
    function setUniswapFactory(address uniswapV3Factory) public returns (address) {
        v3Factory = IUniswapV3Factory(uniswapV3Factory);
        return address(v3Factory);
    }

    /// @dev Gets the observation index range for a Uniswap V3 pool
    /// @param uniswapV3Pool The Uniswap V3 pool for which to get observation indices
    /// @return observationEnd The last observation index
    /// @return observationStart The first observation index
    function getFullPoolStateRange(IUniswapV3Pool uniswapV3Pool)
        internal
        view
        returns (uint16 observationEnd, uint16 observationStart)
    {
        (,, uint16 observationIndex, uint16 currentCardinality,,,) = uniswapV3Pool.slot0();

        require(
            currentCardinality > 1,
            "Pool does not have enough observations, please increase the cardinality of the pool"
        );

        return (uint16(0), observationIndex);
    }

    /// @notice Retrieves liquidity and slot0 data from a given Uniswap V3 pool
    /// @param pool The Uniswap V3 pool from which to fetch data
    /// @param previousCardinality The last observed cardinality
    /// @return Liquidity of the pool, slot0 data, and the difference in cardinality
    function getLiquidityAndSlot0(IUniswapV3Pool pool, uint16 previousCardinality)
        public
        view
        isNotZeroAddress(address(pool))
        isValidUniswapV3Pool(pool)
        returns (uint128, IUniswapV3Pool.Slot0 memory slot0, uint16)
    {
        (
            slot0.sqrtPriceX96,
            slot0.tick,
            slot0.observationIndex,
            slot0.observationCardinality,
            slot0.observationCardinalityNext,
            ,
        ) = pool.slot0();
        return (pool.liquidity(), slot0, slot0.observationCardinality - previousCardinality);
    }

    /// @notice Returns the observation data for a given Uniswap V3 pool
    /// @param pool The Uniswap V3 pool for which to get observation data
    /// @return Array of observation data
    function getFullObservationsArray(IUniswapV3Pool pool) public view returns (ObservationData[] memory) {
        (uint16 observationStart, uint16 observationEnd) = getFullPoolStateRange(pool);
        ObservationData[] memory pricesMemory = new ObservationData[](observationEnd-observationStart);
        for (uint16 i = observationStart; i < observationEnd; i++) {
            (uint32 blockTimestampBefore, int56 tickCumulativeBefore,,) = pool.observations(i);
            (uint32 blockTimestampNow, int56 tickCumulativeNow,,) = pool.observations(i + 1);
            uint160 price = TickMath.getSqrtRatioAtTick(
                int24((tickCumulativeNow - tickCumulativeBefore) / int56(blockTimestampNow - blockTimestampBefore))
            );
            pricesMemory[i - observationStart].price = price;
            //get the time estimate inbetween observations
            pricesMemory[i - observationStart].timestamp = blockTimestampNow;
            //save the result in our mapping so each pool has
        }
        return pricesMemory;
    }

    /// @notice Returns the observation data for a Uniswap V3 pool identified by tokens and fee tier
    /// @param baseToken The base token of the Uniswap V3 pool
    /// @param quoteToken The quote token of the Uniswap V3 pool
    /// @param feeTier The fee tier of the Uniswap V3 pool
    /// @return Array of observation data
    function getFullObservationsArray(IERC20TokenV06 baseToken, IERC20TokenV06 quoteToken, uint24 feeTier)
        public
        view
        returns (ObservationData[] memory)
    {
        IUniswapV3Pool uniswapV3Pool = IUniswapV3Pool(getPoolAddress(address(baseToken), address(quoteToken), feeTier));
        require(address(uniswapV3Pool) != address(0), "No existing Uniswap V3 Pool");

        (uint16 observationStart, uint16 observationEnd) = getFullPoolStateRange(uniswapV3Pool);
        ObservationData[] memory pricesMemory = new ObservationData[](observationEnd-observationStart);
        for (uint16 i = observationStart; i < observationEnd; i++) {
            (uint32 blockTimestampBefore, int56 tickCumulativeBefore,,) = uniswapV3Pool.observations(i);
            (uint32 blockTimestampNow, int56 tickCumulativeNow,,) = uniswapV3Pool.observations(i + 1);
            uint160 price = TickMath.getSqrtRatioAtTick(
                int24((tickCumulativeNow - tickCumulativeBefore) / int56(blockTimestampNow - blockTimestampBefore))
            );

            pricesMemory[i - observationStart].price = price;
            //get the time estimate inbetween observations
            pricesMemory[i - observationStart].timestamp = blockTimestampNow;
            //save the result in our mapping so each pool has
        }
        return pricesMemory;
    }
}
