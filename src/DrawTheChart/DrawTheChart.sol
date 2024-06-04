// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
/// @title DrawTheChart
/// @author dextracker
/// @notice This contract is used to manage predictive games based on price movements
/// @dev Utilizes MerkleProof for claim verification and other utilities for game management

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {DtcManager} from '@DrawTheChart/DtcClaimManager.sol';

contract DrawTheChart is DtcManager {
    constructor(address initialOwner) Ownable(initialOwner) {}

    /*//////////////////////////////////////////////////////////////
                            GAMEPLAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new game with the specified parameters
    /// @param startBlock The block number when the game will start
    /// @param endBlock The block number when the game will end
    /// @param entryFee The fee required to enter the game
    /// @param pool The uniswap pool involved in the game
    /// @param fee The fee percentage for the protocol
    /// @param split Enable a protocol fee split for the creator of
    /// the game if the creator is not the owner of the contract
    /// @return game The index of the newly created game

    function createGame(
        uint128 startBlock,
        uint128 endBlock,
        uint128 entryFee,
        address pool,
        uint8 fee,
        bool split
    ) public payable returns (uint64 game) {
        //must create a game for a future block
        if (startBlock - block.number == 0) {
            revert InvalidStartBlock();
        }
        //must have a fee less than 20%
        if (fee > 20) {
            revert InvalidFeeAmount();
        }

        games.push();

        game = uint64(games.length - 1);
        games[game].startBlock = startBlock;
        games[game].endBlock = endBlock;
        games[game].entryFee = entryFee;
        games[game].fee = fee;
        games[game].pool = pool;
        //if the caller is not from an EOA use tx.origin to track ownership
        //can happen in metatx where msg.senders gas is paid, or on delegate call from sc wallet
        // when msg.sender == tx.origin caller is an EOA, if msg.sender != tx.origin caller is a contract
        games[game].creator = msg.sender != tx.origin ? tx.origin : msg.sender;
        games[game].protocolFeeSplit = split;
        games[game].uniqueId = bytes32(
            keccak256(
                abi.encodePacked(
                    game,
                    msg.sender != tx.origin ? tx.origin : msg.sender
                )
            )
        );

        // dont need to set these as solidity will init these to 0 automatically on creation of Game
        //~1k gas saved on create
        // games[game].ended = false;
        // games[game].creatorBalance = 0;
        // games[game].protocolBalance = 0;
        emit GameCreated(
            game,
            games[game].fee,
            games[game].entryFee,
            block.number,
            games[game].startBlock,
            games[game].endBlock,
            games[game].creator,
            games[game].pool
        );

        if (msg.value > 0) {
            this.sponsorGame{value: msg.value}(game);
        }
    }

    /// @notice Enter an existing game
    /// @param gameIndex The index of the game to enter
    /// @param predictedPricesHash The hash of the predicted prices for the game. keccak256(predictedPrices.map(() => {keccak256(abi.encode(price,timestamp))})
    /// @return game , entry , entry index : The index of the game entered, packed data, and the new total entries count
    function enterGame(
        uint64 gameIndex,
        bytes32 predictedPricesHash,
        bytes32 ipfsCid
    )
        external
        payable
        nonReentrant
        onlyIfNotEntered(gameIndex, msg.sender)
        returns (uint64 game, bytes memory packedEntry, uint256 entriesIndex)
    {
        Game storage currentGame = games[gameIndex];

        if (gameIndex > games.length) {
            revert InvalidGameIndex(gameIndex, games.length);
        }

        if (block.number > currentGame.startBlock) {
            revert GameAlreadyStarted(currentGame.startBlock, block.number);
        }

        if (msg.value != currentGame.entryFee) {
            revert EntryFeeNotMet(msg.value, currentGame.entryFee);
        }

        uint128 depositAmountMinusFee = uint128(msg.value) -
            uint128((msg.value * currentGame.fee) / 100);
        packedEntry = packEntry(
            msg.sender,
            predictedPricesHash,
            depositAmountMinusFee,
            ipfsCid
        );

        currentGame.entries.push(packedEntry);
        currentGame.deposits[msg.sender] = depositAmountMinusFee;
        currentGame.totalDeposits += depositAmountMinusFee;

        bool shouldSplitFees = currentGame.protocolFeeSplit;

        //split the fee in half to the creator or take the whole fee as protocol fee
        uint128 _fee = shouldSplitFees
            ? uint128((msg.value * (currentGame.fee / 2)) / 100)
            : uint128((msg.value * currentGame.fee) / 100);

        (uint128 creatorFee, uint128 protocolFee) = shouldSplitFees
            ? (_fee, _fee)
            : (0, _fee);
        currentGame.protocolBalance += protocolFee;

        if (shouldSplitFees) {
            currentGame.creatorBalance += creatorFee;
        }
        emit GameEntered(msg.sender, uint128(currentGame.entries.length));
        return (gameIndex, packedEntry, currentGame.entries.length);
    }
}
