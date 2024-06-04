// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {DrawTheChart} from '@DrawTheChart/DrawTheChart.sol';
import {DtcGameManager} from '@DrawTheChart/DtcGameManagement.sol';
import {TestUtils} from './testUtils/testUtils.sol';
import {Test} from 'forge-std/Test.sol';
import {ProtocolWallet} from '@WtchTwrDefi/DummyProtocolWallet.sol';
import {DummySmartContractWallet} from '@WtchTwrDefi/DummySCWallet.sol';

interface DTCdelegateCall {
    function createGame(
        uint128 startBlock,
        uint128 endBlock,
        uint128 entryFee,
        address pool,
        uint8 fee,
        bool split
    ) external returns (uint64 game);
}

contract DrawTheChartTest is Test, TestUtils {
    DrawTheChart dtc;
    TestUtils testUtils = new TestUtils();

    address public dummyAddress1;
    address public dummyAddress2;
    address public dummyAddress3;
    address public dummyAddress4;
    address public dummyAddress5;
    address public wallet;
    uint256 public baseBlockTime = 2 minutes;
    uint256 public gameDurationInBlocks = 5;
    uint128 public depositAmountRequired = 1216000000000000;
    string public symbolEmoji = '\xF0\x9F\x94\xAE';
    uint256 public FEE = 10;
    uint128 start;
    uint128 end;

    // Fallback function for this contract.
    receive() external payable {}

    function setUp() public {
        dummyAddress1 = address(
            uint160(uint256(keccak256(abi.encodePacked('dummy1'))))
        );
        vm.deal(dummyAddress1, 10e18);
        dummyAddress2 = address(
            uint160(uint256(keccak256(abi.encodePacked('dummy2'))))
        );
        vm.deal(dummyAddress2, 10e18);
        dummyAddress3 = address(
            uint160(uint256(keccak256(abi.encodePacked('dummy3'))))
        );
        vm.deal(dummyAddress3, 10e18);
        dummyAddress4 = address(
            uint160(uint256(keccak256(abi.encodePacked('dummy4'))))
        );
        vm.deal(dummyAddress4, 10e18);
        dummyAddress5 = address(
            uint160(uint256(keccak256(abi.encodePacked('dummy5'))))
        );
        ProtocolWallet _wallet = new ProtocolWallet();
        wallet = address(_wallet);

        start = uint128(block.number + 1);
        end = uint128(block.number + gameDurationInBlocks);

        vm.deal(dummyAddress5, 10e18);
        vm.label(dummyAddress1, 'DrawTheChart:Participant 1');
        vm.label(dummyAddress2, 'DrawTheChart:Participant 2');
        vm.label(dummyAddress3, 'DrawTheChart:Participant 3');
        vm.label(dummyAddress4, 'DrawTheChart:Participant 4');
        vm.label(dummyAddress5, 'DrawTheChart:Participant 5');
        vm.label(wallet, 'DrawTheChart:Protocol Wallet');
        vm.label(address(dtc), 'DrawTheChart:DrawTheChartController');
        dtc = new DrawTheChart(address(this));
        vm.roll(1);
        dtc.createGame(
            start,
            end,
            depositAmountRequired,
            WETH,
            uint8(FEE),
            true
        );
        vm.roll(2);
    }

    function testCreateGame() public {
        assert(address(this) == dtc.owner());
        (
            uint128 startBlock,
            uint128 endBlock,
            uint128 protocolBalance,
            uint128 creatorBalance,
            uint128 totalDeposits,
            uint128 entryFee,
            uint8 fee,
            bool ended,
            address pool,
            address creator,
            bool protocolFeeSplit,
            bytes32 claimMerkleRoot
        ) = dtc.getGame(0);

        assert(startBlock == start);
        assert(protocolBalance == 0);
        assert(creatorBalance == 0);
        assert(totalDeposits == 0);
        assert(fee == FEE);
        assert(protocolFeeSplit == true);
        assert(pool == WETH);
        assert(creator == dtc.getCreator(0));
        assert(claimMerkleRoot == bytes32(0));
        assert(entryFee == depositAmountRequired);
        assert(ended == false);
        uint256 _endBlock = (block.number - 1 + (gameDurationInBlocks));
        assert(endBlock == _endBlock);
        emit log_string(
            string(abi.encodePacked(checkmark, ' Game Created Successfully'))
        );
    }

    function testGetGameInfoExtended() public {}

    function testCreateGameSCWallet() public {
        DummySmartContractWallet dscw = new DummySmartContractWallet();
        vm.label(address(dscw), 'Dummy Smart Contract Wallet');
        //prank msg.sender and origin
        vm.startPrank(dummyAddress1, address(dscw));

        uint64 game = dtc.createGame(
            start + 1,
            end + 1,
            depositAmountRequired,
            WETH,
            uint8(FEE),
            true
        );
        vm.stopPrank();
        assert(address(dscw) == dtc.getCreator(game));
        (
            uint128 startBlock,
            uint128 endBlock,
            uint128 protocolBalance,
            uint128 creatorBalance,
            uint128 totalDeposits,
            uint128 entryFee,
            uint8 fee,
            bool ended,
            address pool,
            address creator,
            bool protocolFeeSplit,
            bytes32 claimMerkleRoot
        ) = dtc.getGame(0);
        assert(startBlock == start);
        assert(protocolBalance == 0);
        assert(creatorBalance == 0);
        assert(totalDeposits == 0);
        assert(fee == FEE);
        assert(protocolFeeSplit == true);
        assert(pool == WETH);
        assert(creator == dtc.getCreator(0));
        assert(claimMerkleRoot == bytes32(0));
        assert(entryFee == depositAmountRequired);
        assert(ended == false);
        uint256 _endBlock = (block.number - 1 + (gameDurationInBlocks));
        assert(endBlock == _endBlock);
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' Game Created Successfully When msg.sender != tx.origin'
                )
            )
        );
    }

    function testMultipleGameProtocolFeeClaim() public {
        start = uint128(block.number + 1);
        end = uint128(block.number + gameDurationInBlocks);
        //game 1
        uint64 game1 = dtc.createGame(
            start,
            end,
            depositAmountRequired,
            WETH,
            uint8(FEE),
            true
        );
        //game 2
        uint64 game2 = dtc.createGame(
            start,
            end,
            depositAmountRequired,
            WETH,
            uint8(FEE),
            true
        );

        enterGameMultipleHelper(game1);
        enterGameMultipleHelper(game2);

        uint64[] memory indexes = new uint64[](2);
        indexes[0] = game1;
        indexes[1] = game2;

        vm.prank(dummyAddress1, dummyAddress1);
        vm.expectRevert();
        dtc.claimProtocolFeesMultiple(indexes, address(this));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' ProtocolFeeClaim not allowed for non owner'
                )
            )
        );

        vm.expectRevert();
        dtc.claimProtocolFeesMultiple(indexes, address(0));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' ProtocolFeeClaim not allowed to address(0)'
                )
            )
        );

        dtc.claimProtocolFeesMultiple(indexes, address(this));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' Can claim protocol fees from multiple games'
                )
            )
        );
    }

    function testEndGame() public {
        //make sure we arent the owner
        vm.prank(dummyAddress1);
        vm.expectRevert();
        dtc.endGame(0);
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' Cannot end game early'
                )
            )
        );

        vm.roll(gameDurationInBlocks + 1);

        vm.prank(dummyAddress1);
        vm.expectRevert();
        dtc.endGame(0);
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' Cannot end game if not the owner of the contract or creator of the game'
                )
            )
        );

        vm.prank(address(dtc.owner()));
        dtc.endGame(0);
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    symbolEmoji,
                    ' Can end game if owner'
                )
            )
        );
    }

    function testClaimCreatorFees() public {
        vm.roll(1);
        enterGameMultipleHelper(uint64(0));

        vm.roll(gameDurationInBlocks + 2);

        emit log_string(
            string(abi.encodePacked(symbolEmoji, ' Claiming creator fees'))
        );
        vm.prank(address(dtc.owner()));
        dtc.endGame(0);

        address creator = dtc.getCreator(0);
        vm.startPrank(creator);
        (, uint256 amount) = dtc.claimCreatorFees(0);
        emit log_named_uint('Amount claimed', amount);
        uint256 requiredFee = (4 *
            depositAmountRequired *
            dtc.getProtocolFeeForGame(0)) / 100;
        emit log_named_uint('requiredFee', requiredFee / 2);
        require(amount == requiredFee / 2, 'Did not withdraw enough fees');
    }

    function enterGameMultipleHelper(uint64 gameIndex) public {
        vm.prank(dummyAddress5, dummyAddress5);
        dtc.enterGame{value: depositAmountRequired}(gameIndex, bytes32(0), '');
        vm.prank(dummyAddress2, dummyAddress2);
        dtc.enterGame{value: depositAmountRequired}(gameIndex, bytes32(0), '');
        vm.prank(dummyAddress3, dummyAddress2);
        dtc.enterGame{value: depositAmountRequired}(gameIndex, bytes32(0), '');
        vm.prank(dummyAddress4, dummyAddress2);
        dtc.enterGame{value: depositAmountRequired}(gameIndex, bytes32(0), '');
    }

    function testWithdrawProtocolFees() public {
        vm.roll(1);
        enterGameMultipleHelper(uint64(0));

        dtc.getEntriesForGame(uint64(0));

        vm.roll(gameDurationInBlocks + 2);
        dtc.endGame(0);
        uint256 bal = address(wallet).balance;
        vm.expectRevert();
        dtc.claimProtocolFees(0, address(0));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Cannot claim protocol fees to address(0)'
                )
            )
        );

        vm.expectRevert();
        dtc.claimProtocolFees(1, address(0));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Cannot claim protocol fees for another game'
                )
            )
        );

        vm.prank(dummyAddress1);
        vm.expectRevert();
        dtc.claimProtocolFees(1, address(0));
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Cannot claim protocol fees as non-owner'
                )
            )
        );

        emit log_named_uint('Amount claimed', bal);
        dtc.claimProtocolFees(0, address(wallet));
        bal = address(wallet).balance;
        emit log_named_uint('Amount claimed', bal);
        require(bal == 243200000000000, 'Did not withdraw enough fees');
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Can claim protocol fees'
                )
            )
        );
    }

    function testEntry() public {
        vm.roll(gameDurationInBlocks - gameDurationInBlocks);
        vm.prank(dummyAddress1, dummyAddress1);
        vm.expectRevert();
        dtc.enterGame{value: 1}(0, bytes32(0), '');
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Cannot enter game with incorrect entry fee'
                )
            )
        );

        vm.prank(dummyAddress1, dummyAddress1);
        dtc.enterGame{value: depositAmountRequired}(0, bytes32(0), '');
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Can enter game with corrent entry fee'
                )
            )
        );

        vm.prank(dummyAddress1, dummyAddress1);
        vm.expectRevert();
        dtc.enterGame{value: depositAmountRequired}(0, bytes32(0), '');
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Cannot enter a game twice'
                )
            )
        );
    }

    function testSponsorGame() public {
        vm.roll(0);
        dtc.sponsorGame{value: 3e18}(0);
        require(address(dtc).balance == 3e18, 'Sponsorship failed');
        emit log_string(
            string(
                abi.encodePacked(
                    checkmark,
                    ' ',
                    littleMan,
                    ' Can sponsor a game'
                )
            )
        );
    }

    function testFuzz_EnterGame(
        address entrant,
        uint256 point1,
        uint256 point2,
        bytes32 ipfsCid
    ) public {
        vm.roll(gameDurationInBlocks - gameDurationInBlocks);
        vm.assume(entrant != address(this));
        //random address entry into game
        vm.startPrank(entrant, entrant);
        vm.deal(entrant, depositAmountRequired);
        //enter game with an array with a single {x,y} point

        dtc.enterGame{value: depositAmountRequired}(
            0,
            bytes32(
                keccak256(
                    abi.encodePacked(
                        keccak256(abi.encodePacked(point1)),
                        keccak256(abi.encodePacked(point2))
                    )
                )
            ),
            ipfsCid
        );
        emit log_string(
            string(
                abi.encodePacked(checkmark, ' ', littleMan, ' can enter game')
            )
        );
    }
}
