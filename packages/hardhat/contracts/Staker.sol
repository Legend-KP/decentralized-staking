// SPDX-License-Identifier: MIT
pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;
    
    // Track individual staker balances
    mapping(address => uint256) public balances;

    // Threshold to trigger success
    uint256 public constant threshold = 1 ether;

    // Deadline for staking period
    uint256 public deadline = block.timestamp + 30 seconds;

    // Flag to allow withdrawals if threshold not met by deadline
    bool public openForWithdraw;

    // Emitted on every stake for frontend event list
    event Stake(address indexed, uint256);

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
    // (Make sure to add a `Stake(address,uint256)` event and emit it for the frontend `All Stakings` tab to display)
    function stake() public payable notCompleted {
        require(msg.value > 0, "no value");
        require(block.timestamp < deadline, "staking period over");

        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    // After some `deadline` allow anyone to call an `execute()` function
    // If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`
    function execute() external notCompleted {
        require(block.timestamp >= deadline, "deadline not reached");

        uint256 contractBalance = address(this).balance;
        if (contractBalance >= threshold) {
            // Success path: forward all funds to external contract and mark completed there
            exampleExternalContract.complete{value: contractBalance}();
        } else {
            // Failure path: open withdrawals
            openForWithdraw = true;
        }
    }

    // If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balance
    function withdraw() external notCompleted {
        require(openForWithdraw, "withdrawals closed");
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "no balance");

        // Effects
        balances[msg.sender] = 0;

        // Interaction
        (bool success, ) = payable(msg.sender).call{value: userBalance}("");
        require(success, "withdraw failed");
    }

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    // Add the `receive()` special function that receives eth and calls stake()
    receive() external payable {
        stake();
    }

    // Protect actions while external contract is not completed
    modifier notCompleted() {
        require(!exampleExternalContract.completed(), "already completed");
        _;
    }
}
