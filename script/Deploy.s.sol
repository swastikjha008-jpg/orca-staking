// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {OrcaCoin} from "../src/OrcaCoin.sol";
import {StakingContract} from "../src/StakingContract.sol";

/// @notice Deploys OrcaCoin + StakingContract and wires them together.
/// @dev Local:   pnpm anvil   then   PRIVATE_KEY=0x... pnpm deploy:local
///      Sepolia: set SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY then pnpm deploy:sepolia
contract Deploy is Script {
    function run() external returns (OrcaCoin orca, StakingContract staking) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        orca = new OrcaCoin(deployer);
        staking = new StakingContract(orca);
        orca.updateStakingContract(address(staking));
        vm.stopBroadcast();

        console.log("Owner:           ", deployer);
        console.log("OrcaCoin:        ", address(orca));
        console.log("StakingContract: ", address(staking));
    }
}
