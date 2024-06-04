// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title DtcErrors - A library of custom error messages for the DrawTheChart contract.
 * @dev These error messages are used for providing descriptive error information.
 */
abstract contract DtcErrors {
    /**
     * @dev Throws an error when a zero address is involved in a transfer.
     * @param reason The reason for the zero address transfer error.
     */
    error ZeroAddressTransfer(string reason);

    /**
     * @dev Throws an error when an invalid sender is detected.
     */
    error InvalidSender();

    /**
     * @dev Throws an error when an invalid creator is detected.
     */
    error InvalidCreator();

    /**
     * @dev Throws an error when an invalid caller is detected for batchCreateGame.
     */
    error InvalidCaller(address msgSender, address txOrigin, address owner);

    /**
     * @dev Throws an error when a creator of a game tries to enter a game they created.
     */
    error CreatorCannotEnterGame(
        address creator,
        address caller,
        address txOrigin
    );

    /**
     * @dev Throws an error when an invalid game index is provided.
     * @param index The invalid game index.
     * @param length The length of the game-related data structure.
     */
    error InvalidGameIndex(uint64 index, uint256 length);

    /**
     * @dev Throws an error when the provided indices length is invalid.
     */
    error InvalidIndicesLength();

    /**
     * @dev Throws an error when an Ethereum transaction lacks attached Ether.
     */
    error NoAttachedEth();

    /**
     * @dev Throws an error when no deposit is found.
     */
    error NoDepositFound();

    /**
     * @dev Throws an error when a claim operation fails.
     */
    error ClaimFailed();

    /**
     * @dev Throws an error when a claim transfer fails.
     */
    error ClaimTransferFailed();

    /**
     * @dev Throws an error when claiming creator fees is unsuccessful.
     */
    error UnableToClaimCreatorFees();

    /**
     * @dev Throws an error when the entry fee is not met.
     * @param amountSent The amount sent by the user.
     * @param amountRequired The required entry fee amount.
     */
    error EntryFeeNotMet(uint256 amountSent, uint256 amountRequired);

    /**
     * @dev Throws an error when the contract balance is too low to fulfill a request.
     * @param amountRequested The requested amount.
     * @param amountAvailable The available balance.
     */
    error ContractBalanceTooLow(
        uint128 amountRequested,
        uint128 amountAvailable
    );

    /**
     * @dev Throws an error when a protocol fee claim operation fails.
     * @param success Whether the claim was successful.
     * @param amountClaimed The claimed amount.
     * @param targetBalance The target balance.
     */
    error ProtocolFeeClaimFailed(
        bool success,
        uint128 amountClaimed,
        uint256 targetBalance
    );

    /**
     * @dev Throws an error when a non-protocol claim is attempted.
     */
    error NonProtocolClaim();

    /**
     * @dev Throws an error when the end block is invalid.
     */
    error InvalidEndBlock();

    /**
     * @dev Throws an error when the fee amount is invalid.
     */
    error InvalidFeeAmount();

    /**
     * @dev Throws an error when the start block is invalid.
     */
    error InvalidStartBlock();

    /**
     * @dev Throws an error when a game is ended.
     */
    error GameEnded();

    /**
     * @dev Throws an error when a game is not ended.
     */
    error GameNotEnded();

    /**
     * @dev Throws an error when a game has not started.
     */
    error GameNotStarted();

    /**
     * @dev Throws an error when a game has already ended.
     */
    error GameAlreadyEnded();

    /**
     * @dev Throws an error when a user has already entered a game.
     * @param gameIndex The index of the game.
     */
    error GameAlreadyEntered(uint256 gameIndex);

    /**
     * @dev Throws an error when a game has already started.
     * @param block The block number when the game started.
     * @param currentBlock The current block number.
     */
    error GameAlreadyStarted(uint256 block, uint256 currentBlock);

    /**
     * @dev Throws an error when a game has not finished.
     * @param currentBlock The current block number.
     * @param gameEndBlock The block number when the game ends.
     */
    error GameNotFinished(uint256 currentBlock, uint256 gameEndBlock);

    /**
     * @dev Throws an error when a Merkle root has already been set for a game.
     */
    error MerkleRootPreviouslySet();

    /**
     * @dev Throws an error when proof verification fails.
     */
    error ProofVerificationFailed();

    /**
     * @dev Throws an error when there is a mismatch in leaf context.
     * @param sender The address of the sender.
     * @param amount The amount.
     * @param leaf The leaf context.
     */
    error LeafContextMismatch(address sender, uint128 amount, bytes32 leaf);
}
