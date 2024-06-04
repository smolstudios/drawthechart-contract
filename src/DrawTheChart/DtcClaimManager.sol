pragma solidity ^0.8.21;

import {DtcEvents} from '@DrawTheChart/DtcEvents.sol';
import {DtcGameManager} from '@DrawTheChart/DtcGameManagement.sol';
import {DtcMerkleVerifier} from '@DrawTheChart/DtcMerkleVerifier.sol';
import {ReentrancyGuard} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol';

abstract contract DtcManager is
    ReentrancyGuard,
    DtcMerkleVerifier,
    DtcGameManager
{
    /// @notice Claims fees for the protocol
    /// @param indicies An array of game indicies to claim fees from
    /// @param target The address to send fees to
    /// @return success , amountClaimed, the claim success and amount claimed
    function claimProtocolFeesMultiple(
        uint64[] memory indicies,
        address target
    )
        external
        onlyOwner
        nonReentrant
        returns (bool success, uint128 amountClaimed)
    {
        if (indicies.length == 0) {
            revert InvalidIndicesLength();
        }
        if (target == address(0)) {
            revert ZeroAddressTransfer('No transfers to the zero address');
        }

        //accumulate balances from multiple games
        uint128 multipleGameBalance;
        for (uint64 i = 0; i < uint64(indicies.length); i++) {
            multipleGameBalance += games[indicies[i]].protocolBalance;
            //set balances to 0 so we cant withdraw more than once from this game
            games[indicies[i]].protocolBalance = 0;
        }

        uint128 balB = uint128(target.balance);

        (success, ) = payable(target).call{value: multipleGameBalance}('');
        //calculate how much was transfered to the target in this transaction
        amountClaimed = uint128(target.balance) - balB;
        //make sure our transfer was successful and that the balance of the target matches the protocol balance we intended to withdraw
        if (!(success == true && amountClaimed == multipleGameBalance)) {
            revert ProtocolFeeClaimFailed(
                success,
                amountClaimed,
                multipleGameBalance
            );
        }
    }

    /// @notice Claims fees for the protocol
    /// @param gameIndex The index of the game to claim fees from
    /// @param target The address to send fees to
    /// @return success , amountClaimed, the claim success and amount claimed
    function claimProtocolFees(
        uint64 gameIndex,
        address target
    )
        external
        gameEnded(gameIndex)
        onlyOwner
        nonReentrant
        returns (bool success, uint128 amountClaimed)
    {
        if (target == address(0)) {
            revert ZeroAddressTransfer('No transfers to the zero address');
        }

        // get the current protocol balance for a specific game
        uint256 balance = games[gameIndex].protocolBalance;
        //set to 0 before claiming the winnings
        games[gameIndex].protocolBalance = 0;
        //keep track of the targets balance before transfer
        uint128 balB = uint128(target.balance);
        //perform the transfer
        (success, ) = payable(target).call{value: balance}('');
        //calculate how much was transfered to the target in this transaction
        amountClaimed = uint128(target.balance) - balB;
        //make sure our transfer was successful and that the balance of the target
        //matches the protocol balance we intended to withdraw;
        if (!(success == true && amountClaimed == balance)) {
            revert ProtocolFeeClaimFailed(success, amountClaimed, balance);
        }
    }

    /// @notice Claims fees for the creator of a game
    /// @param gameIndex The index of the game to claim fees from
    /// @return success , amount, the claim success and amount claimed
    function claimCreatorFees(
        uint64 gameIndex
    )
        external
        onlyCreator(gameIndex)
        isCreatorClaimable(gameIndex)
        gameEnded(gameIndex)
        nonReentrant
        returns (bool success, uint128 amount)
    {
        //load game into storage as well will be doing multiple reads/writes
        Game storage game = games[gameIndex];
        //claim fees for the creator
        uint256 balance = game.creator.balance;
        uint256 feeBalance = game.creatorBalance;
        //set the claimable balance to 0
        game.creatorBalance = 0;

        (success, ) = payable(game.creator).call{value: feeBalance}('');
        if (!success) {
            revert UnableToClaimCreatorFees();
        }
        amount = uint128(game.creator.balance - balance);
        emit CreatorFeeClaimed(gameIndex, game.creator, amount);
    }

    /// @notice Claim the winnings for a game
    /// @param target The index of the game to claim winnings from
    /// @param gameIndex The index of the game to claim winnings from
    /// @param proof An array of bytes32 values forming the Merkle proof
    /// @param amount The amount to claim
    /// @param leaf The leaf to verify for the claim
    /// @return success True if the claim was successful, otherwise false, claimedAmount
    function claimWinnings(
        address target,
        uint64 gameIndex,
        bytes32[] calldata proof,
        uint128 amount,
        bytes32 leaf
    )
        external
        gameEnded(gameIndex)
        nonReentrant
        returns (bool success, uint128 claimedAmount)
    {
        //load game into storage as well will be doing multiple reads/writes
        Game storage game = games[gameIndex];

        //validation to prevent entrants from claiming deposits from other games
        //@todo move into a modifier to cleanup function
        if (leaf != keccak256(abi.encodePacked(msg.sender, amount))) {
            revert LeafContextMismatch(msg.sender, amount, leaf);
        }

        //verify merkle proof
        //@todo move into a modifier to cleanup function
        if (!(verifyProof(proof, game.claimMerkleRoot, leaf))) {
            revert ProofVerificationFailed();
        }

        //make sure the user deposited enough to claim
        if (game.deposits[target] < (game.entryFee * game.fee) / 100) {
            revert NoDepositFound();
        }

        //make sure there is enough balance on the contract to pay out
        if (game.totalDeposits <= amount) {
            revert ContractBalanceTooLow(
                amount,
                uint128(address(this).balance)
            );
        }
        //set to 0 before claiming the winnings
        game.deposits[target] = 0;

        (success, ) = payable(target).call{value: amount}('');
        if (!success) {
            revert ClaimTransferFailed();
        }
        claimedAmount = amount;
    }
}
