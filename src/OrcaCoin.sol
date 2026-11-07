// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title OrcaCoin
/// @notice ERC-20 reward token. Tokens are only created ("minted") by the staking contract
///         when a staker claims their rewards. The owner decides which contract that is.
contract OrcaCoin is ERC20, Ownable {
    /// @notice The only address allowed to call `mint`.
    address public stakingContract;

    event StakingContractUpdated(address indexed oldStakingContract, address indexed newStakingContract);

    error NotStakingContract();
    error ZeroAddress();

    modifier onlyStakingContract() {
        if (msg.sender != stakingContract) revert NotStakingContract();
        _;
    }

    constructor(address initialOwner) ERC20("OrcaCoin", "ORCA") Ownable(initialOwner) {}

    /// @notice Point the token at the staking contract that is allowed to mint. Owner only.
    function updateStakingContract(address newStakingContract) external onlyOwner {
        if (newStakingContract == address(0)) revert ZeroAddress();
        emit StakingContractUpdated(stakingContract, newStakingContract);
        stakingContract = newStakingContract;
    }

    /// @notice Mint reward tokens. Staking contract only.
    function mint(address to, uint256 amount) external onlyStakingContract {
        _mint(to, amount);
    }
}
