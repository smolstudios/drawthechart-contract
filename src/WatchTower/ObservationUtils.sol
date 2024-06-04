pragma solidity ^0.7.6;
pragma abicoder v2;

library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

library SafeMath {
    uint256 constant WAD = 10 ** 18; // 1 WAD is 10^18

    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b + WAD / 2) / WAD;
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * WAD + b / 2) / b;
    }

    function wadAdd(uint256 x, uint256 y) internal pure returns (uint256) {
        return add(x, y);
    }

    function wadSub(uint256 x, uint256 y) internal pure returns (uint256) {
        return sub(x, y);
    }

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "SafeMath: addition overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "SafeMath: subtraction overflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "SafeMath: multiplication overflow");
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y > 0, "SafeMath: division by zero");
        z = x / y;
    }

    function roundDownToSignificantDigits(uint256 x, uint256 significantDigits) internal pure returns (uint256) {
        require(significantDigits <= 18, "Significant digits must be less or equal to 18");
        uint256 factor = 10 ** (18 - significantDigits);
        return (x / factor) * factor;
    }
}

library EvenOdd {
    function isEven(uint256 number) internal pure returns (bool) {
        return number % 2 == 0;
    }

    function isOdd(uint256 number) internal pure returns (bool) {
        return number % 2 != 0;
    }
}

contract PackUnpackUint32 {
    function packUint32(uint32 a, uint32 b) internal pure returns (uint256) {
        return (uint256(a) << 32) | uint256(b);
    }

    function unpackUint32(uint256 c) internal pure returns (uint32, uint32) {
        uint32 a = uint32(c >> 32);
        uint32 b = uint32(c);
        return (a, b);
    }
}

interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgo)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );

    function liquidity() external view returns (uint128);

    struct Observation {
        // the block timestamp of the observation
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pool was first initialized
        int56 tickCumulative;
        // the seconds per liquidity, i.e. seconds elapsed / max(1, liquidity) since the pool was first initialized
        uint160 secondsPerLiquidityCumulativeX128;
        // whether or not the observation is initialized
        bool initialized;
    }

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint8 feeProtocol;
        bool unlocked;
    }

    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}
