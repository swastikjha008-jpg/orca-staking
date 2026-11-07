// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrcaCoin} from "../src/OrcaCoin.sol";
import {StakingContract} from "../src/StakingContract.sol";

/// @dev Tries to re-enter `unstake` from its ETH receive hook.
contract ReentrantStaker {
    StakingContract public immutable staking;
    bool public attacked;

    constructor(StakingContract _staking) {
        staking = _staking;
    }

    function attack() external payable {
        staking.stake{value: msg.value}();
        staking.unstake(msg.value / 2);
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // Re-entering is blocked by nonReentrant; the revert bubbles up so the ETH send fails.
            staking.unstake(1);
        }
    }
}

contract StakingTest is Test {
    OrcaCoin orca;
    StakingContract staking;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);
        orca = new OrcaCoin(owner);
        staking = new StakingContract(orca);
        orca.updateStakingContract(address(staking));
        vm.stopPrank();

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // ---------------------------------------------------------------- stake

    function test_stake() public {
        vm.expectEmit(true, false, false, true);
        emit Staked(alice, 2 ether);
        vm.prank(alice);
        staking.stake{value: 2 ether}();

        assertEq(staking.stakedBalance(alice), 2 ether);
        assertEq(staking.totalStaked(), 2 ether);
        assertEq(address(staking).balance, 2 ether);
    }

    function test_stakeZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingContract.ZeroAmount.selector);
        staking.stake();
    }

    function test_constructorRejectsZeroToken() public {
        vm.expectRevert(StakingContract.ZeroAddress.selector);
        new StakingContract(OrcaCoin(address(0)));
    }

    // -------------------------------------------------------------- rewards

    function test_noRewardsRightAfterStaking() public {
        vm.prank(alice);
        staking.stake{value: 1 ether}();
        assertEq(staking.getRewards(alice), 0);
    }

    function test_oneEthOneDayEarnsOneOrca() public {
        vm.prank(alice);
        staking.stake{value: 1 ether}();

        skip(1 days);
        assertEq(staking.getRewards(alice), 1 ether);
    }

    function test_rewardsScaleWithAmountAndTime() public {
        vm.prank(alice);
        staking.stake{value: 5 ether}();

        skip(3 days);
        assertEq(staking.getRewards(alice), 15 ether);
    }

    function test_rewardsAreIndependentPerUser() public {
        vm.prank(alice);
        staking.stake{value: 1 ether}();
        skip(1 days);
        vm.prank(bob);
        staking.stake{value: 2 ether}();
        skip(1 days);

        assertEq(staking.getRewards(alice), 2 ether); // 1 ETH x 2 days
        assertEq(staking.getRewards(bob), 2 ether); //   2 ETH x 1 day
    }

    function test_getRewardsForNonStakerIsZero() public view {
        assertEq(staking.getRewards(alice), 0);
    }

    function test_topUpSettlesPreviousRewards() public {
        vm.startPrank(alice);
        staking.stake{value: 1 ether}();
        skip(1 days);
        staking.stake{value: 1 ether}(); // settles 1 ORCA, now earning on 2 ETH
        vm.stopPrank();

        assertEq(staking.getRewards(alice), 1 ether);
        skip(1 days);
        assertEq(staking.getRewards(alice), 3 ether);
    }

    // ---------------------------------------------------------------- claim

    function test_claimRewardsMintsOrca() public {
        vm.prank(alice);
        staking.stake{value: 2 ether}();
        skip(2 days);

        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(alice, 4 ether);
        vm.prank(alice);
        staking.claimRewards();

        assertEq(orca.balanceOf(alice), 4 ether);
        assertEq(orca.totalSupply(), 4 ether);
        assertEq(staking.getRewards(alice), 0);
    }

    function test_claimWithNothingReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingContract.NoRewards.selector);
        staking.claimRewards();
    }

    function test_cannotClaimTwiceInSameBlock() public {
        vm.startPrank(alice);
        staking.stake{value: 1 ether}();
        skip(1 days);
        staking.claimRewards();
        vm.expectRevert(StakingContract.NoRewards.selector);
        staking.claimRewards();
        vm.stopPrank();
    }

    function test_canClaimAgainAfterMoreTime() public {
        vm.startPrank(alice);
        staking.stake{value: 1 ether}();
        skip(1 days);
        staking.claimRewards();
        skip(1 days);
        staking.claimRewards();
        vm.stopPrank();

        assertEq(orca.balanceOf(alice), 2 ether);
    }

    // -------------------------------------------------------------- unstake

    function test_unstakeReturnsEth() public {
        vm.startPrank(alice);
        staking.stake{value: 3 ether}();

        vm.expectEmit(true, false, false, true);
        emit Unstaked(alice, 1 ether);
        staking.unstake(1 ether);
        vm.stopPrank();

        assertEq(staking.stakedBalance(alice), 2 ether);
        assertEq(staking.totalStaked(), 2 ether);
        assertEq(alice.balance, 98 ether);
    }

    function test_unstakeKeepsEarnedRewards() public {
        vm.startPrank(alice);
        staking.stake{value: 1 ether}();
        skip(1 days);
        staking.unstake(1 ether); // fully out
        vm.stopPrank();

        assertEq(staking.getRewards(alice), 1 ether);
        skip(5 days);
        assertEq(staking.getRewards(alice), 1 ether); // nothing more accrues

        vm.prank(alice);
        staking.claimRewards();
        assertEq(orca.balanceOf(alice), 1 ether);
    }

    function test_unstakeMoreThanStakedReverts() public {
        vm.startPrank(alice);
        staking.stake{value: 1 ether}();
        vm.expectRevert(StakingContract.InsufficientStake.selector);
        staking.unstake(2 ether);
        vm.stopPrank();
    }

    function test_unstakeZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingContract.ZeroAmount.selector);
        staking.unstake(0);
    }

    function test_cannotUnstakeOthersFunds() public {
        vm.prank(alice);
        staking.stake{value: 1 ether}();

        vm.prank(bob);
        vm.expectRevert(StakingContract.InsufficientStake.selector);
        staking.unstake(1 ether);
    }

    function test_reentrancyOnUnstakeIsBlocked() public {
        ReentrantStaker attacker = new ReentrantStaker(staking);
        vm.deal(address(attacker), 2 ether);

        vm.expectRevert(StakingContract.TransferFailed.selector);
        attacker.attack{value: 2 ether}();

        assertEq(staking.totalStaked(), 0); // whole tx reverted
    }

    // ---------------------------------------------------------------- fuzz

    function testFuzz_rewardsMatchFormula(uint96 amount, uint32 duration) public {
        amount = uint96(bound(amount, 1, 1_000 ether));
        vm.deal(alice, amount);

        vm.prank(alice);
        staking.stake{value: amount}();
        skip(duration);

        uint256 expected = (uint256(amount) * duration) / 1 days;
        assertEq(staking.getRewards(alice), expected);

        if (expected > 0) {
            vm.prank(alice);
            staking.claimRewards();
            assertEq(orca.balanceOf(alice), expected);
        }
    }

    function testFuzz_stakeUnstakeRoundTrip(uint96 amount) public {
        amount = uint96(bound(amount, 1, 100 ether));

        vm.startPrank(alice);
        staking.stake{value: amount}();
        staking.unstake(amount);
        vm.stopPrank();

        assertEq(alice.balance, 100 ether);
        assertEq(address(staking).balance, 0);
        assertEq(staking.totalStaked(), 0);
    }

    /// @dev Contract ETH balance always equals the sum of everyone's stake.
    function testFuzz_solvency(uint96 a, uint96 b, uint96 withdrawA) public {
        a = uint96(bound(a, 1, 50 ether));
        b = uint96(bound(b, 1, 50 ether));
        withdrawA = uint96(bound(withdrawA, 1, a));

        vm.prank(alice);
        staking.stake{value: a}();
        vm.prank(bob);
        staking.stake{value: b}();
        vm.prank(alice);
        staking.unstake(withdrawA);

        assertEq(address(staking).balance, staking.totalStaked());
        assertEq(staking.totalStaked(), staking.stakedBalance(alice) + staking.stakedBalance(bob));
    }
}
