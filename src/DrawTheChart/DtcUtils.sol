// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
/**
 * @title DtcUtils
 * @dev Utility functions for packing and unpacking data related to DrawTheChart game entries.
 */

contract DtcUtils {
    /**
     * @notice Pack an address, a bytes32 value, and a uint256 into a bytes value.
     * @dev This function takes in multiple individual variables and packs them into a single bytes memory object.
     * @param entrant The address of the entrant.
     * @param predictedPricesHash The hashed price predictions.
     * @param depositAmount The amount of deposit.
     * @param ipfsCid The CID of the predicted prices for a user. (Optional: pass empty string if not needed)
     * @return The packed bytes data containing all three parameters.
     */
    function packEntry(address entrant, bytes32 predictedPricesHash, uint128 depositAmount, bytes32 ipfsCid)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory packed = abi.encode(entrant, predictedPricesHash, depositAmount, ipfsCid);
        return packed;
    }

    /**
     * @notice Unpack a bytes value into an address, a bytes32 value, and a uint256.
     * @dev This function takes in a packed bytes memory object and unpacks it into individual variables.
     * @param _packed The packed bytes data to be unpacked.
     * @return entrant The address of the entrant, predictedPricesHash The hashed price predictions, depositAmount The amount of deposit, ipfsCid The CID of the predicted prices for a user.
     */
    function unpackEntry(bytes memory _packed)
        public
        pure
        returns (address entrant, bytes32 predictedPricesHash, uint128 depositAmount, bytes32 ipfsCid)
    {
        (entrant, predictedPricesHash, depositAmount, ipfsCid) =
            abi.decode(_packed, (address, bytes32, uint128, bytes32));
        return (entrant, predictedPricesHash, depositAmount, ipfsCid);
    }
}
