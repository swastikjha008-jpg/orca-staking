// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrcaCoin} from "../src/OrcaCoin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OrcaCoinTest is Test {
    OrcaCoin orca;
    address owner = makeAddr("owner");
    address staking = makeAddr("staking");
    address alice = makeAddr("alice");

    event StakingContractUpdated(address indexed oldStakingContract, address indexed newStakingContract);

    function setUp() public {
        orca = new OrcaCoin(owner);
    }

    function test_metadata() public view {
        assertEq(orca.name(), "OrcaCoin");
        assertEq(orca.symbol(), "ORCA");
        assertEq(orca.decimals(), 18);
        assertEq(orca.totalSupply(), 0);
        assertEq(orca.owner(), owner);
    }

    function test_ownerCanUpdateStakingContract() public {
        vm.expectEmit(true, true, false, false);
        emit StakingContractUpdated(address(0), staking);
        vm.prank(owner);
        orca.updateStakingContract(staking);
        assertEq(orca.stakingContract(), staking);
    }

    function test_nonOwnerCannotUpdateStakingContract() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        orca.updateStakingContract(staking);
    }

    function test_cannotSetZeroStakingContract() public {
        vm.prank(owner);
        vm.expectRevert(OrcaCoin.ZeroAddress.selector);
        orca.updateStakingContract(address(0));
    }

    function test_stakingContractCanMint() public {
        vm.prank(owner);
        orca.updateStakingContract(staking);

        vm.prank(staking);
        orca.mint(alice, 5 ether);

        assertEq(orca.balanceOf(alice), 5 ether);
        assertEq(orca.totalSupply(), 5 ether);
    }

    function test_mintRevertsBeforeStakingContractIsSet() public {
        vm.prank(staking);
        vm.expectRevert(OrcaCoin.NotStakingContract.selector);
        orca.mint(alice, 1);
    }

    function test_ownerCannotMintDirectly() public {
        vm.prank(owner);
        orca.updateStakingContract(staking);

        vm.prank(owner);
        vm.expectRevert(OrcaCoin.NotStakingContract.selector);
        orca.mint(alice, 1);
    }

    function test_oldStakingContractLosesMintRights() public {
        address newStaking = makeAddr("newStaking");
        vm.startPrank(owner);
        orca.updateStakingContract(staking);
        orca.updateStakingContract(newStaking);
        vm.stopPrank();

        vm.prank(staking);
        vm.expectRevert(OrcaCoin.NotStakingContract.selector);
        orca.mint(alice, 1);

        vm.prank(newStaking);
        orca.mint(alice, 1);
        assertEq(orca.balanceOf(alice), 1);
    }

    function testFuzz_onlyStakingContractMints(address caller, uint96 amount) public {
        vm.assume(caller != staking);
        vm.prank(owner);
        orca.updateStakingContract(staking);

        vm.prank(caller);
        vm.expectRevert(OrcaCoin.NotStakingContract.selector);
        orca.mint(alice, amount);
    }
}
