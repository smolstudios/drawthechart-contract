// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {UniswapObservationOracle} from "@WtchTwr/UniswapObservationOracle.sol";
// import {Script} "forge-std/Script.sol";

// contract WtchTwr is Script {
//     function setUp() public {}

//     function run() public {
//         // read DEPLOYER_PRIVATE_KEY from environment variables
//         uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

//         // start broadcast any transaction after this point will be submitted to chain
//         vm.startBroadcast(deployerPrivateKey);

//         // deploy AttestationStation
//         UniswapObservationOracle wtchTwr = new UniswapObservationOracle();

//         wtchTwr.setUniswapFactory(address(0x33128a8fC17869897dcE68Ed026d694621f6FDfD));

//         // stop broadcasting transactions
//         vm.stopBroadcast();
//     }
// }
