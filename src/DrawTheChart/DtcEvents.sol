pragma solidity ^0.8.21;

contract DtcEvents {
    /// @notice Event to log the change in entry fee for a game
    event EntryFeeChanged(uint128 indexed previousFee, uint128 indexed newFee, uint128 game);

    /// @notice Event to log the creation of a game
    event GameCreated(
        uint64 gameIndex,
        uint8 fee,
        uint128 entryFee,
        uint256 createdBlock,
        uint256 startBlock,
        uint256 endBlock,
        address creator,
        address pool
    );

    /// @notice Event to log the payout to the winner
    event WinnerPayout(address indexed winner, uint128 indexed amountWon);

    /// @notice Event to log the protocol fee
    event ProtocolFeeTaken(uint128 indexed fee);

    /// @notice Event to log the creator fee
    event CreatorFeeTaken(address indexed creator, uint128 indexed fee);

    /// @notice Event to log when a creator claims fees from a game
    event CreatorFeeClaimed(uint64 indexed gameIndex, address indexed creator, uint128 indexed amountWithdrawn);

    /// @notice Event to log the prediction hash and entrant
    event Prediction(address indexed msgSender, bytes32 predictedPricesHash);

    /// @notice Event to log game entry
    event GameEntered(address indexed msgSender, uint128 indexed packedEntryIndex);

    /// @notice Event to log the initialization of a game payout claim
    event GamePayoutClaimInitialized(bytes32 indexed gameRoot, uint256 indexed gameIndex);

    /// @notice Event to log the details of a sponsorship of a game
    event Sponsorship(address indexed sponsor, uint128 indexed amountDeposited, uint128 indexed totalDeposits);
}
