pragma solidity ^0.8.21;

// test contract that performs a delegate call to the TargetContract
contract DummySmartContractWallet {
    function delegateCallCreateGame(
        address targetContract,
        uint128 startBlock,
        uint128 endBlock,
        uint128 entryFee,
        address pool,
        uint8 fee,
        bool split
    ) public returns (uint64 game) {
        // Perform a delegate call to the createGame function of the target contract
        (bool success, bytes memory result) = targetContract.delegatecall(
            abi.encodeWithSignature(
                "createGame(uint128,uint128,uint128,address,uint8,bool)",
                startBlock,
                endBlock,
                entryFee,
                pool,
                fee,
                split
            )
        );

        require(success, "Delegate call failed");

        // Parse the result from the delegate call
        assembly {
            game := mload(add(result, 0x20))
        }
    }
}
