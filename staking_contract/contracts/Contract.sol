// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract masterchefStake is Ownable {
    using SafeERC20 for IERC20;

    uint public startTime;
    uint public endTime;
    address public stakingToken;
    address public rewardToken;
    uint256 private constant REWARDS_PRECISION = 1e12;

    constructor(
        uint _startTime,
        uint _endTime,
        address _stakingToken,
        address _rewardToken
    ) {
        startTime = block.timestamp + _startTime;
        endTime = block.timestamp + _endTime;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;

        // give the rewarders role to owner
        rewarders[msg.sender] = true;
    }

    struct userInfo {
        uint amount;
        uint rewardDebt;
    }

    struct poolInfo {
        uint totalTokens;
        uint accRewardPerShare;
        uint totalRewards;
    }

    mapping(address => userInfo) stakers;

    // rewarders role manage
    mapping(address => bool) rewarders;

    poolInfo public pool;

    event Deposite(address indexed staker, uint amount);
    event Withdraw(address indexed staker, uint amount);
    event HarvestRewards(address indexed staker, uint amount);
    event ReceiveReward(address indexed user, uint amount);

    function deposite(uint _amount) external {
        require(_amount > 0, "you should deposite more than 0 token");
        require(
            block.timestamp >= startTime,
            "you should wait until startTime"
        );
        userInfo storage staker = stakers[msg.sender];
        harvestRewards();

        // prevent the reendtrancy attack using  transfer => update => emit
        IERC20(stakingToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        staker.amount += _amount;
        staker.rewardDebt =
            (staker.amount * pool.accRewardPerShare) /
            REWARDS_PRECISION;
        pool.totalTokens += _amount;
        emit Deposite(msg.sender, _amount);
    }

    function withdraw(uint _amount) external {
        require(
            block.timestamp > endTime,
            "you should withdraw wait until endTime"
        );
        userInfo storage staker = stakers[msg.sender];
        require(
            _amount <= staker.amount,
            "you can not withdraw your requirement"
        );
        require(_amount > 0, "you can not withdraw 0 token");
        harvestRewards();

        // prevent the reentrancy attack using update => transfer => emit
        staker.amount -= _amount;
        staker.rewardDebt =
            (staker.amount * pool.accRewardPerShare) /
            REWARDS_PRECISION;
        pool.totalTokens -= _amount;
        IERC20(stakingToken).safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function harvestRewards() public {
        userInfo storage staker = stakers[msg.sender];
        uint pending = (staker.amount * pool.accRewardPerShare) /
            REWARDS_PRECISION -
            staker.rewardDebt;

        // prevent the reentrancy attack using update => transfer => emit
        staker.rewardDebt =
            (staker.amount * pool.accRewardPerShare) /
            REWARDS_PRECISION;
            if(pending > 0) {
        IERC20(rewardToken).safeTransfer(msg.sender, pending);
        emit HarvestRewards(msg.sender, pending);}
    }

    function receiveReward(uint _amount) public {
        if (pool.totalTokens == 0) return;
        require(
            rewarders[msg.sender] == true,
            "you can not call this function"
        );
        require(_amount > 0, "you should give rewards more than 0 token");

        // prevent the reendtrancy attack using  transfer => update => emit
        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        pool.accRewardPerShare +=
            (_amount * REWARDS_PRECISION) /
            pool.totalTokens;
        pool.totalRewards += _amount;
        emit ReceiveReward(msg.sender, _amount);
    }

    function getPool()
        public
        view
        returns (uint totalTokens, uint totalRewards)
    {
        totalTokens = pool.totalTokens;
        totalRewards = pool.totalRewards;
    }

    // show the claimable rewards for any account
    function pendingRewards(
        address user
    ) public view returns (uint pendingrewards) {
        userInfo storage staker = stakers[user];
        pendingrewards =
            (staker.amount * pool.accRewardPerShare) /
            REWARDS_PRECISION -
            staker.rewardDebt;
    }

    // manage the rewarders role
    function registerMods(address[] calldata _users) public onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            rewarders[_users[i]] = true;
        }
    }

    function removeMods(address[] calldata _users) public onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            rewarders[_users[i]] = false;
        }
    }
}
