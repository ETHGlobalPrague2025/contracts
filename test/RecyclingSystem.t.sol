// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RecyclingSystem} from "../src/RecyclingSystem.sol";

contract RecyclingSystemTest is Test {
    RecyclingSystem public recyclingSystem;
    address public staker1;
    address public staker2;
    address public collector;

    function setUp() public {
        recyclingSystem = new RecyclingSystem();
        staker1 = makeAddr("staker1");
        staker2 = makeAddr("staker2");
        collector = makeAddr("collector");

        // Fund test addresses
        vm.deal(staker1, 100 ether);
        vm.deal(staker2, 100 ether);
        vm.deal(collector, 100 ether);
    }

    function test_CreatePendingGarbageCan() public {
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);
        
        // Stake the full amount to trigger deployment and verify events
        vm.prank(staker1);
        vm.expectEmit(true, true, false, true);
        emit RecyclingSystem.GarbageCanDeployed(0, 0);
        vm.expectEmit(true, true, false, true);
        emit RecyclingSystem.GarbageCanCreated(0, "New York City");
        recyclingSystem.stakeForGarbageCan{value: 1 ether}(0);
    }

    function test_StakeForGarbageCan() public {
        // Create a pending garbage can
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);

        // Stake from staker1
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: 0.6 ether}(0);

        // Stake from staker2 and expect deployment events
        vm.prank(staker2);
        vm.expectEmit(true, true, false, true);
        emit RecyclingSystem.GarbageCanDeployed(0, 0);
        vm.expectEmit(true, true, false, true);
        emit RecyclingSystem.GarbageCanCreated(0, "New York City");
        recyclingSystem.stakeForGarbageCan{value: 0.4 ether}(0);
    }

    function test_UpdateFillLevel() public {
        // Create and fund a garbage can
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: 1 ether}(0);

        // Update fill level
        recyclingSystem.updateFillLevel(0, RecyclingSystem.RecyclableType.PLASTIC, 100, 0.1 ether);

        // Verify the update through getGarbageCanInfo
        (
            ,  // location
            uint256 currentValue,
            bool isActive,
            bool isLocked,
            ,  // deploymentTimestamp
            ,  // lastEmptiedTimestamp
            uint256 totalStaked
        ) = recyclingSystem.getGarbageCanInfo(0);

        assertEq(currentValue, 0.1 ether, "Current value should be updated");
        assertEq(totalStaked, 1 ether, "Total staked amount should be correct");
        assertTrue(isActive, "Garbage can should be active");
        assertFalse(isLocked, "Garbage can should not be locked");
    }

    function test_BuyContents() public {
        // Create and fund a garbage can
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: 1 ether}(0);

        // Add some recyclables
        recyclingSystem.updateFillLevel(0, RecyclingSystem.RecyclableType.PLASTIC, 100, 0.5 ether);

        // Buy contents as collector
        vm.prank(collector);
        recyclingSystem.buyContents{value: 0.5 ether}(0);

        // Verify the garbage can was emptied
        (
            ,
            uint256 currentValue,
            ,
            ,
            ,
            uint256 lastEmptiedTimestamp,
        ) = recyclingSystem.getGarbageCanInfo(0);

        assertEq(currentValue, 0, "Current value should be reset to 0");
        assertEq(lastEmptiedTimestamp, block.timestamp, "Last emptied timestamp should be updated");
    }

    function test_WithdrawRewards() public {
        // Create and fund a garbage can
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: 1 ether}(0);

        // Add recyclables and have collector buy them
        recyclingSystem.updateFillLevel(0, RecyclingSystem.RecyclableType.PLASTIC, 100, 1 ether);
        
        vm.prank(collector);
        recyclingSystem.buyContents{value: 1 ether}(0);

        // Record staker1's balance before withdrawal
        uint256 balanceBefore = staker1.balance;

        // Withdraw rewards
        vm.prank(staker1);
        recyclingSystem.withdrawRewards();

        // Verify rewards were received (should be 50% of 1 ether)
        assertEq(
            staker1.balance - balanceBefore,
            0.5 ether,
            "Staker should receive 50% of the contents value"
        );
    }

    function test_GetStakerShare() public {
        // Create a pending garbage can
        recyclingSystem.createPendingGarbageCan("New York City", 1 ether);

        // Stake from two stakers
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: 0.6 ether}(0);

        vm.prank(staker2);
        recyclingSystem.stakeForGarbageCan{value: 0.4 ether}(0);

        // Check staker shares
        uint256 staker1Share = recyclingSystem.getStakerShare(0, staker1);
        uint256 staker2Share = recyclingSystem.getStakerShare(0, staker2);

        assertEq(staker1Share, 6000, "Staker1 should have 60% share (6000 basis points)");
        assertEq(staker2Share, 4000, "Staker2 should have 40% share (4000 basis points)");
    }

    function testFuzz_StakeAmount(uint256 amount) public {
        // Bound the amount to something reasonable (between 0.1 and 10 ether)
        amount = bound(amount, 0.1 ether, 10 ether);

        // Create a pending garbage can with the fuzzed amount as target
        recyclingSystem.createPendingGarbageCan("New York City", amount);

        // Fund the staker with enough ETH
        vm.deal(staker1, amount);

        // Stake the full amount
        vm.prank(staker1);
        recyclingSystem.stakeForGarbageCan{value: amount}(0);

        // Verify the garbage can was deployed with correct total staked
        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 totalStaked
        ) = recyclingSystem.getGarbageCanInfo(0);

        assertEq(totalStaked, amount, "Total staked amount should match input");
    }
}
