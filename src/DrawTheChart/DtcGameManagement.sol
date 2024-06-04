pragma solidity ^0.8.21;

import {DtcEvents} from "@DrawTheChart/DtcEvents.sol";
import {DtcErrors} from "@DrawTheChart/DtcErrors.sol";
import {DtcUtils} from "@DrawTheChart/DtcUtils.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract DtcGameManager is Ownable, DtcUtils, DtcEvents, DtcErrors {
    /// @notice Mapping to store entries in packed format
    mapping(uint256 => uint256) internal entries;

    Game[] internal games;

    /// @dev Struct to represent a game
    /*
        slot0
        uint128 startBlock;   // 16 bytes
        uint128 endBlock;     // 16 bytes

        slot1
        uint128 totalDeposits; // 16 bytes
        uint128 protocolBalance; // 16 bytes

        slot2
        uint128 entryFee;     // 16 bytes
        uint128 creatorBalance; // 16 bytes

        slot3
            {23 bytes room for 9 more}
        uint8 fee;            // 1 byte
        uint8 gameEnded;      // 1 byte
        bool protocolFeeSplit; // 1 byte
        address pool;        // 20 bytes (address)
        
        slot4
            {20 bytes room for 12 more}
        address creator;     // 20 bytes (address)
        bytes32 claimMerkleRoot; // 32 bytes

        slot5
        bytes[] entries;    //variable size
    */
    struct Game {
        uint128 startBlock; // the block to start the game
        uint128 endBlock; // the block to end the game. (max 1 week in blocks ((7*24*60*60)/(chain block time in seconds)))
        uint128 protocolBalance; // fee tracking for protocol
        uint128 creatorBalance; // fee tracking for creators
        uint128 totalDeposits; // the total amount of eth that has been deposited to this game
        uint128 entryFee; // the required entry fee for the game
        uint8 fee; // the protocol fee to take per game. 10 => 10% fee (max 20%)
        bool ended; // bool value to keep track of whether a game has been ended by the creator or not.
        address pool; // address of uniswap pool
        address creator; // address of the creator of the game
        bool protocolFeeSplit; // enable protocol fee splitting if creator of the game is not the owner of this contract
        bytes32 claimMerkleRoot; // the merkle root used to verify claims
        bytes32 uniqueId; // the merkle root used to verify claims
        bytes[] entries; // array of abi encoded entries for the game
        mapping(address => uint256) deposits; // mapping to keep track of deposits per game
    }

    /// @dev Struct to represent a single entry in a game
    struct Entry {
        uint128 depositAmount;
        bytes32 predictedPrice;
        address entrant;
        bytes32 ipfsCid;
    }

    /// @dev Struct to represent observation data
    struct ObservationData {
        uint256 price;
        uint256 timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Modifier to check if the caller is the creator of a given game
    modifier onlyCreator(uint64 gameIndex) {
        _checkCreator(gameIndex);
        _;
    }

    modifier onlyDrawTheChart() {
        _checkIfDtcIsCaller();
        _;
    }

    modifier onlyNotCreator(uint64 gameIndex) {
        _checkIfCreatorNotCaller(gameIndex);
        _;
    }

    /// @dev Modifier to check if a given game uses a fee split
    modifier isCreatorClaimable(uint64 gameIndex) {
        _checkCreatorClaimable(gameIndex);
        _;
    }

    /// @dev Modifier to check if the game has not yet started
    modifier gameNotStarted(uint64 game) {
        _checkGameNotStarted(game);
        _;
    }

    /// @dev Modifier to check if the game is currently active
    modifier gameStarted(uint64 game) {
        _checkGameStarted(game);
        _;
    }

    /// @dev Modifier to check if the game has not finished
    modifier gameNotEnded(uint64 game) {
        _checkGameNotEnded(game);
        _;
    }

    /// @dev Modifier to check if the game has finished
    modifier gameEnded(uint64 game) {
        _checkGameEnded(game);
        _;
    }

    /// @dev Modifier to check if the merkle root has not been set for a given game
    modifier merkleRootNotSet(uint64 gameIndex) {
        _checkMerkleRootNotSet(gameIndex);
        _;
    }

    /// @dev Modifier to check if the caller has not already entered a given game
    modifier onlyIfNotEntered(uint64 game, address entrant) {
        _checkIfNotEntered(game, entrant);
        _;
    }

    function _checkCreator(uint64 gameIndex) internal view {
        if (games[gameIndex].creator != msg.sender && this.owner() != msg.sender) {
            revert InvalidCreator();
        }
    }

    function _checkIfDtcIsCaller() internal view {
        if (tx.origin != this.owner()) {
            if (msg.sender != this.owner()) {
                revert InvalidCaller(msg.sender, tx.origin, this.owner());
            }
        }
    }

    function _checkIfCreatorNotCaller(uint64 gameIndex) internal view {
        if (games[gameIndex].creator == msg.sender || games[gameIndex].creator == tx.origin) {
            revert CreatorCannotEnterGame(games[gameIndex].creator, msg.sender, tx.origin);
        }
    }

    function _checkCreatorClaimable(uint64 gameIndex) internal view {
        if (games[gameIndex].creator == address(0)) {
            revert NonProtocolClaim();
        }
    }

    function _checkGameNotStarted(uint64 game) internal view {
        if (block.number > games[game].startBlock) {
            revert GameNotStarted();
        }
    }

    function _checkGameStarted(uint64 game) internal view {
        if (block.number < games[game].startBlock) {
            revert GameAlreadyStarted(games[game].startBlock, block.number);
        }
    }

    function _checkGameNotEnded(uint64 game) internal view {
        if (isGameEnded(game)) {
            revert GameEnded();
        }
    }

    function _checkGameEnded(uint64 game) internal view {
        if (!isGameEnded(game)) {
            revert GameNotEnded();
        }
    }

    function _checkMerkleRootNotSet(uint64 gameIndex) internal view {
        if (games[gameIndex].claimMerkleRoot != bytes32(0)) {
            revert MerkleRootPreviouslySet();
        }
    }

    function _checkIfNotEntered(uint64 game, address entrant) internal view {
        if (games[game].deposits[entrant] != 0) {
            revert GameAlreadyEntered(game);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice End a game
    /// @param gameIndex The index of the game to end
    /// @return success = True if the game was successfully ended
    function endGame(uint64 gameIndex) public onlyCreator(gameIndex) returns (bool success) {
        if (gameIndex > games.length) {
            revert InvalidGameIndex(gameIndex, games.length);
        }

        if (block.number < games[gameIndex].endBlock) {
            revert GameNotFinished(block.number, games[gameIndex].endBlock);
        }

        if (games[gameIndex].ended == true) {
            revert GameAlreadyEnded();
        }

        Game storage game = games[gameIndex];
        game.ended = true;
        return true;
    }

    /// @notice Set the Merkle root for a game's claims
    /// @param merkleRoot The new Merkle root for the game
    /// @param gameIndex The index of the game to update
    function setMerkleRootForGame(bytes32 merkleRoot, uint64 gameIndex)
        external
        merkleRootNotSet(gameIndex)
        onlyCreator(gameIndex)
        gameEnded(gameIndex)
        returns (bool success)
    {
        games[gameIndex].claimMerkleRoot = merkleRoot;
        emit GamePayoutClaimInitialized(merkleRoot, gameIndex);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            SPONSORSHIP
    //////////////////////////////////////////////////////////////*/

    /// @notice Sponsor a game with funds without an entry
    /// @param gameIndex The index of the game to end
    /// @return success = True if the sponsorship amount was successfully deposited
    function sponsorGame(uint64 gameIndex)
        external
        payable
        gameNotEnded(gameIndex)
        merkleRootNotSet(gameIndex)
        returns (bool success)
    {
        if (msg.value == 0) {
            revert NoAttachedEth();
        }

        games[gameIndex].totalDeposits += uint128(msg.value);
        emit Sponsorship(msg.sender, uint128(msg.value), games[gameIndex].totalDeposits);
        return true;
    }

    /// @notice Returns the total number of games created.
    /// @return The length of the games array.
    function getGamesLength() public view returns (uint256) {
        return games.length;
    }

    /// @notice Fetches the total deposits for a specific game.
    /// @param gameIndex The index of the game.
    /// @return The total amount deposited for the game.
    function getTotalDepositsForGame(uint64 gameIndex) public view returns (uint128) {
        return games[gameIndex].totalDeposits;
    }

    /// @notice Fetches the entry fee for a specific game.
    /// @param gameIndex The index of the game.
    /// @return entryFee The entry fee for the game.
    function getEntryFeeForGame(uint64 gameIndex) public view returns (uint128) {
        return games[gameIndex].entryFee;
    }

    /// @notice Fetches the protocol fee for a specific game.
    /// @param gameIndex The index of the game.
    /// @return The entry fee for the game.
    function getProtocolFeeForGame(uint64 gameIndex) public view returns (uint8) {
        return games[gameIndex].fee;
    }

    /// @notice Fetches details of a game.
    /// @param index The index of the game.
    /// @return startBlock The start block of the game.
    /// @return endBlock The end block of the game.
    /// @return protocolBalance The protocol balance of the game.
    /// @return creatorBalance The creator balance of the game.
    /// @return totalDeposits The total deposits of the game.
    /// @return entryFee The entry fee of the game.
    /// @return fee The protocol fee of the game.
    /// @return ended The status of the game.
    /// @return pool The address of the uniswap pool.
    /// @return creator The address of the creator.
    /// @return protocolFeeSplit The status of the protocol fee split.
    /// @return claimMerkleRoot The merkle root of the claim.
    function getGame(uint64 index)
        public
        view
        returns (
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
        )
    {
        Game storage game = games[index];

        return (
            game.startBlock,
            game.endBlock,
            game.protocolBalance,
            game.creatorBalance,
            game.totalDeposits,
            game.entryFee,
            game.fee,
            game.ended,
            game.pool,
            game.creator,
            game.protocolFeeSplit,
            game.claimMerkleRoot
        );
    }

    function getEntriesForGame(uint64 gameIndex) public view returns (Entry[] memory) {
        Game storage game = games[gameIndex];
        Entry[] memory _entries = new Entry[](game.entries.length);

        for (uint256 i = 0; i < game.entries.length; i++) {
            bytes memory _entry = game.entries[i];
            Entry memory entry;
            (entry.entrant, entry.predictedPrice, entry.depositAmount, entry.ipfsCid) = unpackEntry(_entry);
            _entries[i] = entry;
        }
        return _entries;
    }

    /// @notice Fetches creator of a game.
    /// @param index The index of the game.
    /// @return The creator address for the game
    function getCreator(uint64 index) public view returns (address) {
        return (games[index].creator);
    }

    /// @notice Fetches uniqueId of a game.
    /// @param index The index of the game.
    /// @return The uniqueId of the game
    function getUniqueId(uint64 index) public view returns (bytes32) {
        return (games[index].uniqueId);
    }

    /// @notice Fetches creator of a game.
    /// @param index The index of the game.
    /// @return the creatorsFeeBalance
    function getCreatorBalance(uint64 index) public view returns (uint256) {
        return (games[index].creatorBalance);
    }

    /// @notice Fetches the number of players in a game.
    /// @param gameIndex The index of the game.
    /// @return players The number of players in the game.
    function getNumberOfPlayers(uint64 gameIndex) public view returns (uint256) {
        return games[gameIndex].entries.length;
    }

    /// @notice Checks if a game has ended.
    /// @param gameIndex The index of the game.
    /// @return ended = True if the game has ended, false otherwise.
    function isGameEnded(uint64 gameIndex) public view returns (bool) {
        return games[gameIndex].ended;
    }

    /// @notice Check if the game can be ended
    /// @param gameIndex The index of the game to check
    /// @return True if the game can be ended, otherwise false
    function isGameEndable(uint64 gameIndex) external view returns (bool) {
        return block.number >= games[gameIndex].endBlock;
    }

    /// @notice Get the ipfs cid of the callers entry
    /// @param gameIndex The index of the game to check
    /// @return ipfsCid if an entry exists
    function getIpfsCid(uint64 gameIndex, uint256 entryIndex) public view returns (bytes32) {
        (,,, bytes32 ipfsCid) = unpackEntry(games[gameIndex].entries[entryIndex]);
        return ipfsCid;
    }
}
