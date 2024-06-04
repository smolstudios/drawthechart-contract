// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import {WtchTwr, IUniswapV3Pool, IUniswapV3Factory, ObservationData, IERC20TokenV06} from "@WtchTwr/WtchTwr.sol";
import "@WtchTwrDefi/TickMath.sol";
import {Test} from "forge-std/Test.sol";

pragma experimental ABIEncoderV2;

contract WtchTwrTest is Test {
    address BALD = 0x27D2DECb4bFC9C76F0309b8E88dec3a601Fe25a8;
    address DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address DAI_GOERLI = 0x174956bDfbCEb6e53089297cce4fE2825E58d92C;
    address USDC_GOERLI = 0x853154e2A5604E5C74a2546E2871Ad44932eB92C;
    string public checkmark = "\xE2\x9C\x85";
    string public littleMan = "\xF0\x9F\x91\xA8";
    string public gearEmoji = "\xE2\x9A\x99";
    address USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address WETH = 0x4200000000000000000000000000000000000006;
    WtchTwr wtchtwr;
    address ethUSDCPool;

    receive() external payable {}

    modifier prankOracle() {
        vm.startPrank(address(this));
        _;
        vm.stopPrank();
    }

    modifier onlyForked() {
        uint256 id;
        assembly {
            id := chainid()
        }
        vm.skip(true);
        _;
    }

    function setUp() public {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 8453) {
            uint256 gasBefore = gasleft();
            wtchtwr = new WtchTwr();
            wtchtwr.setUniswapFactory(address(0x33128a8fC17869897dcE68Ed026d694621f6FDfD));
            emit log_named_uint("gasAfter", gasBefore - gasleft());
            vm.label(USDC, "Circle:Base USDC");
            vm.label(0x1833C6171E0A3389B156eAedB301CFfbf328B463, "Circle:Base USDC proxy");
            vm.label(BALD, "Bald Deployer:Bald");
            vm.label(DAI, "Maker:Dai");
            vm.label(WETH, "WETH9:Base WETH");
            vm.label(0x4C36388bE6F416A29C8d8Eee81C771cE6bE14B18, "UniswapV3: WETH-USDC 5bps pool");
            vm.label(0x33128a8fC17869897dcE68Ed026d694621f6FDfD, "UniswapV3: Factory");
            ethUSDCPool = wtchtwr.getPoolAddress(WETH, USDC, 500);
        }
    }

    function testGetFullObservationsArray() public onlyForked {
        ObservationData[] memory prices =
            wtchtwr.getFullObservationsArray(IUniswapV3Pool(wtchtwr.getPoolAddress(WETH, USDC, 500)));
        for (uint256 i = 0; i < prices.length; i++) {
            emit log_named_uint("Timestamp", prices[i].timestamp);
            emit log_named_uint("Price", prices[i].price);
        }
    }

    function testGetFullObservationsArrayWithLiquidity() public onlyForked {
        ObservationData[] memory prices =
            wtchtwr.getFullObservationsArray(IUniswapV3Pool(wtchtwr.getPoolAddress(WETH, USDC, 500)));
        for (uint256 i = 0; i < prices.length; i++) {
            emit log_named_uint("Timestamp", prices[i].timestamp);
            emit log_named_uint("Price", prices[i].price);
        }
    }

    function testGetPrices() public onlyForked {
        address uniswapV3Pool = wtchtwr.getPoolAddress(address(WETH), address(USDC), uint24(500));
        (,, uint16 observationIndex,,,,) = IUniswapV3Pool(uniswapV3Pool).slot0();
        (uint32 blockTimestampBefore, int56 tickCumulativeBefore,,) =
            IUniswapV3Pool(uniswapV3Pool).observations(observationIndex - 1);
        (uint32 blockTimestampNow, int56 tickCumulativeNow,,) =
            IUniswapV3Pool(uniswapV3Pool).observations(observationIndex);
        int24 averageTick =
            int24((tickCumulativeNow - tickCumulativeBefore) / int56(blockTimestampNow - blockTimestampBefore));
        emit log_named_uint("SqrtRatio at tick", TickMath.getSqrtRatioAtTick(averageTick));
    }

    function testGetObservation() public onlyForked {
        uint256 gasBefore = gasleft();
        wtchtwr.getFullObservationsArray(IUniswapV3Pool(wtchtwr.getPoolAddress(WETH, USDC, 500)));
        uint256 gasAfter = gasBefore - gasleft();
        emit log_named_uint("GasUsed", gasAfter);
    }

    function testGetLiquidityAndSlot() public onlyForked {
        IUniswapV3Pool pool = IUniswapV3Pool(wtchtwr.getPoolAddress(WETH, USDC, 500));
        (,,, uint16 cardinality,,,) = pool.slot0();
        emit log_named_uint("cardinality", cardinality);
        uint16 lastCardinality = cardinality - uint16(1);
        wtchtwr.getLiquidityAndSlot0(pool, lastCardinality);
        wtchtwr.getFullObservationsArray(pool);
    }
}
