// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {DrawTheChart} from '@DrawTheChart/DrawTheChart.sol';
import {Script} from 'forge-std/Script.sol';

contract DTC is Script {
    function setUp() public {}

    function run() public {
        // read DEPLOYER_PRIVATE_KEY from environment variables
        uint chainId;
        assembly {
            chainId := chainid()
        }
        uint256 deployerPrivateKey = vm.envUint('DEPLOYER_PRIVATE_KEY');

        address multisigGoerliBase = 0x44b4aF7FB75CE4844F00dBefC61451778cB4bDd5;
        address multisigBase = 0xF23889d12794F77bD23c7b21213Df9B8be69f101;
        // start broadcast any transaction after this point will be submitted to chain
        vm.startBroadcast(deployerPrivateKey);

        // deploy AttestationStation
        new DrawTheChart(chainId == 8453 ? multisigBase : multisigGoerliBase);

        // stop broadcasting transactions
        vm.stopBroadcast();
    }
}
