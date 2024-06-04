pragma solidity ^0.8.21;

contract ProtocolWallet {
    event Received(address sender, uint256 amount);
    event Withdrawn(address to, uint256 amount);

    // Fallback function to receive Ether
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Function to withdraw Ether
    function withdraw(uint256 amount) public {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    // Function to check contract balance
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
