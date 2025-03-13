//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*
Create a staking smart contract that allows users to stake an ERC20 token, earn rewards over time,
and withdraw both their staked tokens and accumulated rewards.

Requirements:

Users should be able to stake tokens by transferring them into the contract.
Users should be able to withdraw their staked tokens at any time.
Users should be able to claim staking rewards, calculated based on how long they have staked.
The contract owner should be able to:
    Set the reward rate (e.g., 10% per year).
    Withdraw tokens from the contract.
    Transfer ownership.
The contract should use the IERC20 interface for token transfers.
Users must approve the contract to spend their tokens before staking.
Use require statements to enforce conditions like minimum stake amount and sufficient balance for withdrawals.
*/

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns(bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);
    function balanceOf(address account) external view returns(uint256);
    function approve(address spender, uint256 amount) external returns(bool);
    function allowance(address owner, address spender) external view returns(uint256);
}

contract Staking {

    address private _owner;

    //modifier to ensure whoever interacts with the function is the owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "Not the contract owner");
        _;
    }

    IERC20 public stakingToken;
    uint256 public rewardRate;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastStakedTime;

    constructor(address _stakingToken, uint256 _rewardRate) {
        _owner = msg.sender; //sets owner as contract deployer
        stakingToken = IERC20(_stakingToken); //creates instance of the IERC20 interface for the specified ERC20 token
        rewardRate = _rewardRate; //deployer specifies reward rate
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 token");
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Stake failed");
        
        stakedBalance[msg.sender] += amount;
        lastStakedTime[msg.sender] = block.timestamp; //sets stake time as current time
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        require(stakingToken.transfer(msg.sender, amount), "Withdraw failed"); //ensures the ERC20 token transfer to the user is successful
        stakedBalance[msg.sender] -= amount;
    }

    function claimRewards() external {
        uint256 stakedDuration = block.timestamp - lastStakedTime[msg.sender];
        uint256 reward = (stakedBalance[msg.sender] * rewardRate * stakedDuration) / (365 days); //calculates reward
        require(reward > 0, "No rewards available");

        require(stakingToken.transfer(msg.sender, reward), "Reward claim failed");
        lastStakedTime[msg.sender] = block.timestamp;
    }

    //allows owner to set a new reward rate
    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }

    function withdrawContractTokens(uint256 amount) external onlyOwner {
        require(stakingToken.transfer(msg.sender, amount), "Owner withdrawal failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        _owner = newOwner;
    }
}
