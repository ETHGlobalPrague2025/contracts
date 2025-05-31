// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RecyclingSystem.sol";
import "../src/TestUSDC.sol";

contract RecyclingSystemTest is Test {
    RecyclingSystem public recyclingSystem;
    TestUSDC public usdc;

    address public deployer = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public collector = address(4);
    address public device = address(5);

    uint256 public constant INITIAL_BALANCE = 10000 * 10**6; // 10,000 USDC
    uint256 public constant STAKE_AMOUNT = 1000 * 10**6; // 1,000 USDC
    uint256 public constant TARGET_AMOUNT = 2000 * 10**6; // 2,000 USDC

    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy USDC
        usdc = new TestUSDC();
        
        // Deploy RecyclingSystem
        recyclingSystem = new RecyclingSystem(address(usdc));
        
        // Mint USDC to users
        vm.stopPrank();
        
        vm.startPrank(user1);
        usdc.mint(INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(user2);
        usdc.mint(INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(collector);
        usdc.mint(INITIAL_BALANCE);
        vm.stopPrank();
    }

    function testCreatePendingGarbageCan() public {
        vm.startPrank(user1);
        
        // Create a pending garbage can
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // Verify the pending garbage can was created with ID 0
        // We can't directly access the pendingGarbageCans mapping, but we can test it indirectly
        // by staking for it and checking if it accepts the stake
        
        // Approve USDC for staking
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        
        // Stake for the garbage can
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        
        // Check that the stake was accepted
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - STAKE_AMOUNT);
        assertEq(usdc.balanceOf(address(recyclingSystem)), STAKE_AMOUNT);
        
        vm.stopPrank();
    }

    function testStakeForGarbageCan() public {
        // Create a pending garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // User1 stakes
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // User2 stakes
        vm.startPrank(user2);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // Check balances
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - STAKE_AMOUNT);
        assertEq(usdc.balanceOf(user2), INITIAL_BALANCE - STAKE_AMOUNT);
        assertEq(usdc.balanceOf(address(recyclingSystem)), STAKE_AMOUNT * 2);
    }

    function testGarbageCanDeployment() public {
        // Create a pending garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // User1 stakes half the target amount
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // User2 stakes the other half, which should trigger deployment
        vm.startPrank(user2);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // Check that the garbage can was deployed with ID 0
        (
            string memory location,
            uint256 currentValue,
            bool isActive,
            bool isLocked,
            uint256 deploymentTimestamp,
            uint256 lastEmptiedTimestamp,
            uint256 totalStaked
        ) = recyclingSystem.getGarbageCanInfo(0);
        
        assertEq(location, "Test Location");
        assertEq(currentValue, 0);
        assertTrue(isActive);
        assertFalse(isLocked);
        assertEq(deploymentTimestamp, block.timestamp);
        assertEq(lastEmptiedTimestamp, 0);
        assertEq(totalStaked, TARGET_AMOUNT);
        
        // Check staker shares
        uint256 user1Share = recyclingSystem.getStakerShare(0, user1);
        uint256 user2Share = recyclingSystem.getStakerShare(0, user2);
        
        // Each user staked half, so they should each have 50% share (5000 basis points)
        assertEq(user1Share, 5000);
        assertEq(user2Share, 5000);
    }

    function testUpdateFillLevel() public {
        // Create and deploy a garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, TARGET_AMOUNT);
        vm.stopPrank();
        
        // Update fill level
        vm.prank(device);
        recyclingSystem.updateFillLevel(
            0, 
            IRecyclingSystem.RecyclableType.PLASTIC, 
            10, 
            100 * 10**6 // 100 USDC value
        );
        
        // Check that the value was updated
        (
            ,
            uint256 currentValue,
            ,
            ,
            ,
            ,
            
        ) = recyclingSystem.getGarbageCanInfo(0);
        
        assertEq(currentValue, 100 * 10**6);
    }

    function testBuyContents() public {
        // Create and deploy a garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, TARGET_AMOUNT);
        vm.stopPrank();
        
        // Update fill level
        vm.prank(device);
        recyclingSystem.updateFillLevel(
            0, 
            IRecyclingSystem.RecyclableType.PLASTIC, 
            10, 
            100 * 10**6 // 100 USDC value
        );
        
        // Collector buys contents
        vm.startPrank(collector);
        uint256 paymentAmount = (100 * 10**6 * 50 * 100) / 10000; // 50% of value
        usdc.approve(address(recyclingSystem), paymentAmount);
        recyclingSystem.buyContents(0);
        vm.stopPrank();
        
        // Check that the value was reset
        (
            ,
            uint256 currentValue,
            ,
            ,
            ,
            uint256 lastEmptiedTimestamp,
            
        ) = recyclingSystem.getGarbageCanInfo(0);
        
        assertEq(currentValue, 0);
        assertEq(lastEmptiedTimestamp, block.timestamp);
        
        // Check that the collector paid
        assertEq(usdc.balanceOf(collector), INITIAL_BALANCE - paymentAmount);
        
        // Check that the contract received the payment
        assertEq(usdc.balanceOf(address(recyclingSystem)), TARGET_AMOUNT + paymentAmount);
    }

    function testWithdrawRewards() public {
        // Create and deploy a garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, TARGET_AMOUNT);
        vm.stopPrank();
        
        // Update fill level
        vm.prank(device);
        recyclingSystem.updateFillLevel(
            0, 
            IRecyclingSystem.RecyclableType.PLASTIC, 
            10, 
            100 * 10**6 // 100 USDC value
        );
        
        // Collector buys contents
        vm.startPrank(collector);
        uint256 paymentAmount = (100 * 10**6 * 50 * 100) / 10000; // 50% of value
        usdc.approve(address(recyclingSystem), paymentAmount);
        recyclingSystem.buyContents(0);
        vm.stopPrank();
        
        // User1 withdraws rewards
        vm.prank(user1);
        recyclingSystem.withdrawRewards();
        
        // Check that user1 received the rewards
        // Since user1 is the only staker with 100% share, they should receive the full payment
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - TARGET_AMOUNT + paymentAmount);
        
        // Check that the contract no longer has the payment
        assertEq(usdc.balanceOf(address(recyclingSystem)), TARGET_AMOUNT);
    }

    function testMultipleStakersRewards() public {
        // Create a pending garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // User1 stakes half
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // User2 stakes half
        vm.startPrank(user2);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
        
        // Update fill level
        vm.prank(device);
        recyclingSystem.updateFillLevel(
            0, 
            IRecyclingSystem.RecyclableType.PLASTIC, 
            10, 
            100 * 10**6 // 100 USDC value
        );
        
        // Collector buys contents
        vm.startPrank(collector);
        uint256 paymentAmount = (100 * 10**6 * 50 * 100) / 10000; // 50% of value
        usdc.approve(address(recyclingSystem), paymentAmount);
        recyclingSystem.buyContents(0);
        vm.stopPrank();
        
        // User1 withdraws rewards
        vm.prank(user1);
        recyclingSystem.withdrawRewards();
        
        // User2 withdraws rewards
        vm.prank(user2);
        recyclingSystem.withdrawRewards();
        
        // Check that users received their share of rewards
        // Each user should receive half of the payment
        uint256 expectedReward = paymentAmount / 2;
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - STAKE_AMOUNT + expectedReward);
        assertEq(usdc.balanceOf(user2), INITIAL_BALANCE - STAKE_AMOUNT + expectedReward);
        
        // Check that the contract no longer has the payment
        assertEq(usdc.balanceOf(address(recyclingSystem)), TARGET_AMOUNT);
    }

    function test_RevertWhen_CreatePendingGarbageCanWithZeroTarget() public {
        vm.prank(user1);
        vm.expectRevert();
        recyclingSystem.createPendingGarbageCan("Test Location", 0);
    }

    function test_RevertWhen_CreatePendingGarbageCanWithEmptyLocation() public {
        vm.prank(user1);
        vm.expectRevert();
        recyclingSystem.createPendingGarbageCan("", TARGET_AMOUNT);
    }

    function test_RevertWhen_StakeForNonExistentGarbageCan() public {
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        vm.expectRevert();
        recyclingSystem.stakeForGarbageCan(999, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_StakeZeroAmount() public {
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), 0);
        vm.expectRevert();
        recyclingSystem.stakeForGarbageCan(0, 0);
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateFillLevelForNonExistentGarbageCan() public {
        vm.prank(device);
        vm.expectRevert();
        recyclingSystem.updateFillLevel(
            999, 
            IRecyclingSystem.RecyclableType.PLASTIC, 
            10, 
            100 * 10**6
        );
    }

    function test_RevertWhen_BuyContentsForNonExistentGarbageCan() public {
        vm.startPrank(collector);
        usdc.approve(address(recyclingSystem), 100 * 10**6);
        vm.expectRevert();
        recyclingSystem.buyContents(999);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawRewardsWithNoRewards() public {
        vm.prank(user1);
        vm.expectRevert();
        recyclingSystem.withdrawRewards();
    }

    function testStakeMoreThanNeeded() public {
        // Create a pending garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // User1 tries to stake more than needed
        vm.startPrank(user1);
        uint256 extraAmount = TARGET_AMOUNT + 1000 * 10**6;
        usdc.approve(address(recyclingSystem), extraAmount);
        recyclingSystem.stakeForGarbageCan(0, extraAmount);
        vm.stopPrank();
        
        // Check that only the target amount was staked
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - TARGET_AMOUNT);
        assertEq(usdc.balanceOf(address(recyclingSystem)), TARGET_AMOUNT);
        
        // Check that the garbage can was deployed
        (
            ,
            ,
            bool isActive,
            ,
            ,
            ,
            
        ) = recyclingSystem.getGarbageCanInfo(0);
        
        assertTrue(isActive);
    }

    function testStakeAfterDeployment() public {
        // Create a pending garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Test Location", TARGET_AMOUNT);
        
        // User1 stakes the full amount
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, TARGET_AMOUNT);
        vm.stopPrank();
        
        // User2 tries to stake after deployment
        vm.startPrank(user2);
        usdc.approve(address(recyclingSystem), STAKE_AMOUNT);
        vm.expectRevert("Garbage can already deployed");
        recyclingSystem.stakeForGarbageCan(0, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testMultipleGarbageCans() public {
        // Create first garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Location 1", TARGET_AMOUNT);
        
        // Create second garbage can
        vm.prank(user1);
        recyclingSystem.createPendingGarbageCan("Location 2", TARGET_AMOUNT);
        
        // User1 stakes for first garbage can
        vm.startPrank(user1);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(0, TARGET_AMOUNT);
        vm.stopPrank();
        
        // User2 stakes for second garbage can
        vm.startPrank(user2);
        usdc.approve(address(recyclingSystem), TARGET_AMOUNT);
        recyclingSystem.stakeForGarbageCan(1, TARGET_AMOUNT);
        vm.stopPrank();
        
        // Check first garbage can info
        (
            string memory location1,
            ,
            ,
            ,
            ,
            ,
            
        ) = recyclingSystem.getGarbageCanInfo(0);
        
        // Check second garbage can info
        (
            string memory location2,
            ,
            ,
            ,
            ,
            ,
            
        ) = recyclingSystem.getGarbageCanInfo(1);
        
        assertEq(location1, "Location 1");
        assertEq(location2, "Location 2");
        
        // Check staker shares
        uint256 user1ShareCan1 = recyclingSystem.getStakerShare(0, user1);
        uint256 user2ShareCan2 = recyclingSystem.getStakerShare(1, user2);
        
        assertEq(user1ShareCan1, 10000); // 100%
        assertEq(user2ShareCan2, 10000); // 100%
    }
}
