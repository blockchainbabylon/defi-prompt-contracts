//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldFarm {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate = 1000;
    uint256 public totalStaked; //total amount of tokens staked in contract
    address public owner;

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastUpdated;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0");

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        _updateRewards(msg.sender);

        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].lastUpdated = block.timestamp;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "Not enough staked");

        _updateRewards(msg.sender);

        userStake.amount -= _amount;
        totalStaked -= _amount;

        stakingToken.transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() external {
        _updateRewards(msg.sender);

        uint256 reward = stakes[msg.sender].rewardDebt;
        require(reward > 0, "No rewards available");

        stakes[msg.sender].rewardDebt = 0;
        rewardToken.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function _updateRewards(address _user) internal {
        Stake storage userStake = stakes[_user];
        if (userStake.amount > 0) {
            uint256 pending = ((block.timestamp - userStake.lastUpdated) * rewardRate * userStake.amount) / totalStaked;
            userStake.rewardDebt += pending;
        }
        userStake.lastUpdated = block.timestamp;
    }

    function setRewardRate(uint256 _newRate) external {
        require(msg.sender == owner, "Only owner can set rate ");
        rewardRate = _newRate;
    }
}
