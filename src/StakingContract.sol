// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrcaCoin} from "./OrcaCoin.sol";

/// @title StakingContract
/// @notice Stake native ETH and earn OrcaCoin over time. Rewards are minted on claim.
/// @dev Rewards accrue linearly: `REWARD_PER_ETH_PER_DAY` OrcaCoin per 1 ETH staked per day.
///      Per-user bookkeeping is settled on every stake / unstake / claim.
contract StakingContract is ReentrancyGuard {
    /// @notice OrcaCoin (18 decimals) minted per 1 ETH (1e18 wei) staked per day.
    uint256 public constant REWARD_PER_ETH_PER_DAY = 1e18;

    OrcaCoin public immutable orcaCoin;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public unclaimedRewards;
    mapping(address => uint256) public lastUpdateTime;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientStake();
    error NoRewards();
    error TransferFailed();

    constructor(OrcaCoin _orcaCoin) {
        if (address(_orcaCoin) == address(0)) revert ZeroAddress();
        orcaCoin = _orcaCoin;
    }

    /// @dev Settle rewards earned since the last update before balances change.
    modifier updateRewards(address user) {
        unclaimedRewards[user] = _earned(user);
        lastUpdateTime[user] = block.timestamp;
        _;
    }

    /// @notice Stake the ETH sent with this call.
    function stake() external payable nonReentrant updateRewards(msg.sender) {
        if (msg.value == 0) revert ZeroAmount();
        stakedBalance[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    /// @notice Withdraw `amount` wei of your stake. Rewards keep what they already earned.
    function unstake(uint256 amount) external nonReentrant updateRewards(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (amount > stakedBalance[msg.sender]) revert InsufficientStake();

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Mint all earned OrcaCoin to the caller.
    function claimRewards() external nonReentrant updateRewards(msg.sender) {
        uint256 amount = unclaimedRewards[msg.sender];
        if (amount == 0) revert NoRewards();

        unclaimedRewards[msg.sender] = 0;
        orcaCoin.mint(msg.sender, amount);
        emit RewardsClaimed(msg.sender, amount);
    }

    /// @notice Total OrcaCoin `user` could claim right now (settled + still accruing).
    function getRewards(address user) external view returns (uint256) {
        return _earned(user);
    }

    function _earned(address user) internal view returns (uint256) {
        uint256 last = lastUpdateTime[user];
        if (last == 0) return unclaimedRewards[user];
        uint256 elapsed = block.timestamp - last;
        uint256 pending = (stakedBalance[user] * elapsed * REWARD_PER_ETH_PER_DAY) / (1 days * 1e18);
        return unclaimedRewards[user] + pending;
    }
}
