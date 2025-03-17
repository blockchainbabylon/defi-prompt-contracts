//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*
The TimeLockVault contract allows users to deposit Ether and lock it for a specified duration.
If they withdraw before the lock time expires, they incur a penalty.
The contract also lets the owner withdraw all funds held in the contract.

Steps to Implement:

Define a Deposit struct to store the amount and unlock time for each user.
Set the contract owner and penalty rate during deployment.

Deposit Function:

Users can deposit Ether and specify a lock duration.
The contract stores the deposit amount and the unlock time.

Withdraw Function:

Users can withdraw their deposit after the lock duration.
If they withdraw early, they incur a penalty (a percentage of the deposit).
If they withdraw after the lock time, they receive the full deposit.
The penalty is sent to the owner.

Owner Withdrawal:

The owner can withdraw all funds from the contract at any time.
*/

contract TimeLockVault {
    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => Deposit) public deposits;
    uint256 public penaltyRate;
    address public owner;

    event Deposited(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty);
    event OwnerWithdrawal(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _penaltyRate) {
        require(_penaltyRate <= 100, "Penalty too high");
        owner = msg.sender;
        penaltyRate = _penaltyRate; //allows deployer to input penalty rate
    }

    //allows anyone to deposit and set a lock duration time
    function deposit(uint256 _lockDuration) external payable {
        require(msg.value > 0, "No ETH sent");
        require(deposits[msg.sender].amount == 0, "Existing deposit");

        //sets the struct
        deposits[msg.sender] = Deposit({
            amount: msg.value,
            unlockTime: block.timestamp + _lockDuration //current time + lockDuration
        });

        emit Deposited(msg.sender, msg.value, block.timestamp + _lockDuration);
    }

    //allows users to withdraw
    function withdraw() external {
        Deposit memory userDeposit = deposits[msg.sender];
        require(userDeposit.amount > 0, "No deposit found");

        uint256 payout;
        uint256 penalty = 0;

        if(block.timestamp < userDeposit.unlockTime) {
            penalty = (userDeposit.amount * penaltyRate) / 100; //penalty is calculated
            payout = userDeposit.amount - penalty; //deposited amount - penalty fee
        } else {
            payout = userDeposit.amount; //if current time is greater than unlockTime, no penalty
        }

        delete deposits[msg.sender]; //helps prevent reentrancy
        if (penalty > 0) {
            payable(owner).transfer(penalty); //if theres a penalty, owner gets it
        }
        payable(msg.sender).transfer(payout); //regardless of penalty or not, user gets funds back

        emit Withdrawn(msg.sender, payout, penalty);
    }

    //owner can withdraw all funds held on this contract
    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        
        payable(owner).transfer(balance);
        
        emit OwnerWithdrawal(balance);
    }
}
