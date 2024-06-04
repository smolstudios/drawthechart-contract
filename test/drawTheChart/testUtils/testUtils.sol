// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {DrawTheChart} from '@DrawTheChart/DrawTheChart.sol';
import {DtcGameManager} from '@DrawTheChart/DtcGameManagement.sol';
import {Test} from 'forge-std/Test.sol';

contract TestUtils is Test {
    string public checkmark = '\xE2\x9C\x85';
    string public littleMan = '\xF0\x9F\x91\xA8';
    string public gearEmoji = '\xE2\x9A\x99';
    address USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address WETH = 0x4200000000000000000000000000000000000006;

    function createPredictedPrices(
        uint256 minPrice
    )
        public
        view
        returns (DrawTheChart.ObservationData[24] memory predictedPrices)
    {
        for (uint256 i = 0; i < 23; i++) {
            predictedPrices[i] = (
                DtcGameManager.ObservationData(
                    minPrice + i,
                    block.timestamp + (60 minutes) * i //prices for every hour in 24 hours
                )
            );
        }
        return predictedPrices;
    }

    function createEntry(
        uint64 game,
        address entrant,
        uint256 min,
        address _dtc
    ) public returns (bytes memory packedEntry, uint256 entriesIndex) {
        DrawTheChart dtc = DrawTheChart(_dtc);
        vm.startPrank(entrant);
        vm.deal(entrant, 1e18);
        uint256 fee = dtc.getEntryFeeForGame(0);
        (, packedEntry, entriesIndex) = dtc.enterGame{value: fee}(
            game,
            keccak256(abi.encode(createPredictedPrices(min))),
            ''
        );
        vm.stopPrank();
        uint256 totalDeposits = dtc.getTotalDepositsForGame(game);
        assert(fee % totalDeposits != 0);
        emit log_string(
            string(
                abi.encodePacked(littleMan, ' Entrant: ', vm.toString(entrant))
            )
        );
    }

    /// @dev Generate the JSON entries for the output file
    function generateJsonEntries(
        string memory _inputs,
        string memory _proof,
        string memory _root,
        string memory _leaf,
        uint256 i
    ) public pure returns (string memory) {
        string memory index = string(
            abi.encodePacked('"', vm.toString(i), '"', ': ')
        );
        string memory result = string(
            abi.encodePacked(
                index,
                '{',
                '"inputs":',
                _inputs,
                ',',
                '"proof":',
                _proof,
                ',',
                '"root":"',
                _root,
                '",',
                '"leaf":"',
                _leaf,
                '"',
                '}'
            )
        );

        return result;
    }

    /// @dev Returns the JSON path of the input file
    function getValuesByIndex(
        uint256 i,
        uint256 j
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '.values.',
                    vm.toString(i),
                    '.',
                    vm.toString(j)
                )
            );
    }
}
