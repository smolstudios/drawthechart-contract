# DrawTheChart

**Author:** Smol Studios

## Overview

The `DrawTheChart` smart contract is designed to manage predictive games based on price movements. It provides functionalities for creating and participating in games, managing entries, and claiming winnings. This contract also utilizes MerkleProof for claim verification and incorporates various utilities for game management.

## Features

- Create and manage predictive games based on price movements.
- Securely handle game entries and deposits.
- Verify claims using Merkle proofs.
- Collect protocol fees and distribute winnings.

## Installation

```bash
git submodule update --init --recursive --remote
pnpm i
```

## Testing

```bash
pnpm foundry:test
```

## Documentation

```bash
forge doc --serve --port ${your_specified_port}
```

## Usage

### Contract Owner

The contract owner has special privileges, such as changing the entry fee and ending games.

### Game Creator

The game creator has special privileges, such as receiving a split of fees and ending games.

### Creating a Game

To create a new game, use the `createGame` function, specifying parameters like start block, end block, entry fee, and tokens involved.

```solidity
// Example of creating a new game
const startBlock = 10000;
const endBlock = 11000;
const entryFee = 1 ether;
const token0 = address(token0Contract);
const token1 = address(token1Contract);
const fee = 5; // 5% protocol fee

const gameIndex = contract.createGame(startBlock, endBlock, entryFee, token0, token1, fee);
```

### Entering a Game

Participants can enter an existing game using the `enterGame` function by providing a predicted price hash and the required entry fee.

```solidity
// Example of entering a game
const gameIndex = 0; // Replace with the index of the game you want to enter
const predictedPricesHash = keccak256(abi.encode([array of predicted prices])");

const { game, packedEntry, entriesIndex } = contract.enterGame(gameIndex, predictedPricesHash, {
  value: entryFee,
});
```

## Ending a Game

To end a game, you should use the `endGame(uint256 gameIndex)` function. Only the creator of the game can call this function.

```solidity
/**
 * @notice End a game
 * @param gameIndex The index of the game to end
 * @return success = True if the game was successfully ended
 */
function endGame(uint256 gameIndex) public onlyCreator(gameIndex) returns (bool success)
```

## Claiming Winnings

Participants can claim their winnings from a finished game using the claimWinnings function by providing a Merkle proof, amount, and leaf for the claim.

```solidity
// Example of claiming winnings
const gameIndex = 0; // Replace with the index of the game you participated in
const proof = [proof1, proof2, proof3]; // Replace with the actual Merkle proof
const amount = winningsAmount; // Replace with the amount you want to claim
const leaf = leafHash; // Replace with the leaf hash for your claim

if (contract.claimWinnings(gameIndex, proof, amount, leaf)) {
  console.log("Winnings claimed successfully.");
}
```

## Events

- `EntryFeeChanged`: Log changes in the entry fee for a game.
- `GameCreated`: Log the creation of a new game.
- `WinnerPayout`: Log the payout to the winner.
- `ProtocolFeeTaken`: Log the collection of protocol fees.
- `PredictionFull`: Log the full prediction hash and entrant.
- `GameEntered`: Log a player's entry into a game.
- `GamePayoutClaimInitialized`: Log the initialization of a game payout claim.

## Functions

- `getGamesLength()`: Get the total number of games created.
- `getTotalDepositsForGame(uint256 gameIndex)`: Get the total deposits for a specific game.
- `getFeeForGame(uint256 gameIndex)`: Get the entry fee for a specific game.
- `getGame(uint256 index)`: Get details of a game.
- `getNumberOfPlayers(uint256 gameIndex)`: Get the number of players in a game.
- `isGameEnded(uint256 gameIndex)`: Check if a game has ended.
- `isGameEndable(uint256 gameIndex)`: Check if a game can be ended.
- `setMerkleRootForGame(bytes32 merkleRoot, uint256 gameIndex)`: Set the Merkle root for a game's claims.
