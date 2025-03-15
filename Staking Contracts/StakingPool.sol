//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*
Create a Solidity smart contract where users can stake ETH and earn rewards over time.

The contract should:

Allow users to deposit ETH to stake.
Distribute rewards based on staking duration.
Prevent early withdrawals (or apply a penalty).
Allow users to withdraw their stake + rewards after a set period.
Use a reentrancy guard to prevent attacks.
*/

contract StakingPool {
    
    //struct to hold users deposit info
    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) public stakes;
    uint256 public constant REWARD_RATE = 10; //10% annual reward
    uint256 public constant LOCKUP_PERIOD = 30 days; //minimum amount of time funds are locked
    uint256 public constant FEE_RATE = 2; //2% fee on withdrawals

    address public owner;
    uint256 public collectedFees; //tracks collected fees

    modifier onlyOwner() {
        require(msg.sender == owner, "Sorry, you are not the owner");
        _;
    }

    constructor() {
        owner = msg.sender; //sets deployer as owner
    }

    //allows anyone to stake/deposit their funds
    function stake() external payable {
        require(msg.value > 0, "Must stake ETH");
        require(stakes[msg.sender].amount == 0, "Already staking");

        stakes[msg.sender] = Stake(msg.value, block.timestamp);
    }

    //allows user that deposited to unstake their funds after 30 days
    function unstake() external {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake");
        require(block.timestamp >= userStake.startTime + LOCKUP_PERIOD, "Lockup period not over"); //funds are locked for 30 days

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = userStake.amount + reward;
        uint256 fee = (totalAmount * FEE_RATE) / 100; //calculates fee

        collectedFees += fee; //store collected fees

        delete stakes[msg.sender]; //deletes users stake before transfer to prevent reentrancy attack
        payable(msg.sender).transfer(totalAmount); //transfers initial deposit and lock up period reward
    }

    //function that calculates how extra 
    function calculateReward(address user) public view returns(uint256) {
        Stake memory userStake = stakes[user];
        uint256 stakingDuration = block.timestamp - userStake.startTime; //calculates stake duration
        return (userStake.amount * REWARD_RATE * stakingDuration) / (365 days * 100); //calculates reward
    }

    //allows owner to withdraw fees
    function withdrawFees() external onlyOwner {
        require(collectedFees > 0, "No fees available");
        uint256 amount = collectedFees;
        collectedFees = 0; //prevents possible reentrancy attack
        payable(owner).transfer(amount);
    }

    //returns total balance being held on contract
    function contractBalance() external view returns(uint256) {
        return address(this).balance;
    }

    //allows contract to receive ETH
    receive() external payable {}
}
