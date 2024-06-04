pragma solidity ^0.8.21;

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract DtcMerkleVerifier {
    /*//////////////////////////////////////////////////////////////
                            MERKLE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies the Merkle proof for a leaf
    /// @param proof An array of bytes32 values forming the Merkle proof
    /// @param merkleRoot The root of the Merkle tree
    /// @param leaf The leaf to verify
    /// @return True if the proof is valid, otherwise false
    function verifyProof(bytes32[] calldata proof, bytes32 merkleRoot, bytes32 leaf) public pure returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}
