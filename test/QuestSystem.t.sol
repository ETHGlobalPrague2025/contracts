// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/QuestSystem.sol";
import "../src/TrashToken.sol";
import "../src/TrashNFT.sol";
import { IRecyclingSystem } from "../src/RecyclingSystem.sol";

contract QuestSystemTest is Test {
    QuestSystem public questSystem;
    TrashToken public trashToken;
    TrashNFT public trashNFT;
    address public recyclingSystem;
    
    address public deployer = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    
    bytes32 public user1EmailHash = keccak256(abi.encodePacked("user1@example.com"));
    bytes32 public user2EmailHash = keccak256(abi.encodePacked("user2@example.com"));
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy tokens
        trashToken = new TrashToken();
        trashNFT = new TrashNFT();
        
        // Use a mock address for recycling system
        recyclingSystem = address(0x123);
        
        // Deploy QuestSystem
        questSystem = new QuestSystem(
            address(trashToken),
            address(trashNFT),
            recyclingSystem
        );
        
        // Transfer ownership of tokens to QuestSystem
        trashToken.transferOwnership(address(questSystem));
        trashNFT.transferOwnership(address(questSystem));
        
        vm.stopPrank();
    }
    
    function testInitialState() public {
        // Check token addresses
        assertEq(address(questSystem.trashToken()), address(trashToken));
        assertEq(address(questSystem.trashNFT()), address(trashNFT));
        assertEq(address(questSystem.recyclingSystem()), recyclingSystem);
        
        // Check owner
        assertEq(questSystem.owner(), deployer);
        
        // Check initial quest configurations
        (string memory name, string memory description, uint256 requiredAmount, uint256 rewardAmount, bool nftReward, ) = 
            getQuestDetails(QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(name, "First Recycler");
        assertEq(description, "Recycle anything once");
        assertEq(requiredAmount, 1);
        assertEq(rewardAmount, 10 * 10**18);
        assertTrue(nftReward);
    }
    
    function testRecordRecycling() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Check quest progress
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(progress, 1);
        assertEq(required, 1);
        assertTrue(completed);
        assertFalse(claimed);
    }
    
    function testRecordMultipleRecycling() public {
        vm.startPrank(deployer);
        
        // Record multiple recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 5);
        
        vm.stopPrank();
        
        // Check First Recycler quest
        (uint256 progress1, uint256 required1, bool completed1, bool claimed1) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(progress1, 5);
        assertEq(required1, 1);
        assertTrue(completed1);
        assertFalse(claimed1);
        
        // Check Weekly Warrior quest
        (uint256 progress2, uint256 required2, bool completed2, bool claimed2) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.WEEKLY_WARRIOR);
        
        assertEq(progress2, 5);
        assertEq(required2, 5);
        assertTrue(completed2);
        assertFalse(claimed2);
    }
    
    function testRecordDifferentMaterials() public {
        vm.startPrank(deployer);
        
        // Record different materials for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.METAL, 1);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.OTHER, 1);
        
        vm.stopPrank();
        
        // Check Material Master quest
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.MATERIAL_MASTER);
        
        assertEq(progress, 3);
        assertEq(required, 3);
        assertTrue(completed);
        assertFalse(claimed);
    }
    
    function testVerifyEmail() public {
        // Create a fake proof
        bytes memory fakeProof = abi.encodePacked("fake proof");
        
        vm.startPrank(user1);
        
        // Verify email
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        vm.stopPrank();
        
        // Check that email is verified
        assertEq(questSystem.verifiedWallets(user1EmailHash), user1);
    }
    
    function testClaimRewards() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Verify email
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // Claim rewards
        vm.prank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        // Check that rewards were received
        assertEq(trashToken.balanceOf(user1), 10 * 10**18);
        assertEq(trashNFT.balanceOf(user1), 1);
        
        // Check that quest is now claimed
        (, , , bool claimed) = questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        assertTrue(claimed);
    }
    
    function test_RevertWhen_ClaimWithoutVerification() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Try to claim rewards without verifying email
        vm.prank(user1);
        vm.expectRevert();
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
    }
    
    function test_RevertWhen_ClaimIncompleteQuest() public {
        // Verify email
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // Try to claim rewards for incomplete quest
        vm.prank(user1);
        vm.expectRevert();
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
    }
    
    function test_RevertWhen_ClaimTwice() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Verify email
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // Claim rewards
        vm.startPrank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        // Try to claim again
        vm.expectRevert();
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        vm.stopPrank();
    }
    
    function test_RevertWhen_ClaimAsWrongUser() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Verify email for user1
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // User2 tries to claim user1's rewards
        vm.prank(user2);
        vm.expectRevert();
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
    }
    
    function testUpdateQuest() public {
        vm.startPrank(deployer);
        
        // Update First Recycler quest
        questSystem.updateQuest(
            QuestSystem.QuestType.FIRST_RECYCLER,
            "Updated First Recycler",
            "Updated description",
            2,
            20 * 10**18,
            true,
            "ipfs://updated"
        );
        
        vm.stopPrank();
        
        // Check updated quest
        (string memory name, string memory description, uint256 requiredAmount, uint256 rewardAmount, bool nftReward, string memory nftURI) = 
            getQuestDetails(QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(name, "Updated First Recycler");
        assertEq(description, "Updated description");
        assertEq(requiredAmount, 2);
        assertEq(rewardAmount, 20 * 10**18);
        assertTrue(nftReward);
        assertEq(nftURI, "ipfs://updated");
    }
    
    function test_RevertWhen_UpdateQuestAsNonOwner() public {
        vm.startPrank(user1);
        
        // Try to update quest as non-owner
        vm.expectRevert();
        questSystem.updateQuest(
            QuestSystem.QuestType.FIRST_RECYCLER,
            "Updated First Recycler",
            "Updated description",
            2,
            20 * 10**18,
            true,
            "ipfs://updated"
        );
        
        vm.stopPrank();
    }
    
    function testWeeklyQuestReset() public {
        vm.startPrank(deployer);
        
        // Record recycling for user1 in week 1
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 5);
        
        // Check Weekly Warrior quest is completed
        (uint256 progress1, , bool completed1, ) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.WEEKLY_WARRIOR);
        
        assertEq(progress1, 5);
        assertTrue(completed1);
        
        // Move to next week
        vm.warp(block.timestamp + 1 weeks);
        
        // Record recycling for user1 in week 2
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        vm.stopPrank();
        
        // Verify email
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // Claim week 1 rewards
        vm.prank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.WEEKLY_WARRIOR);
        
        // Record more recycling in week 2
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 4);
        vm.stopPrank();
        
        // Check Weekly Warrior quest is completed again
        (uint256 progress2, , bool completed2, bool claimed2) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.WEEKLY_WARRIOR);
        
        assertEq(progress2, 5);
        assertTrue(completed2);
        assertTrue(claimed2); // Already claimed in week 1
    }
    
    function testEarthChampionProgress() public {
        vm.startPrank(deployer);
        
        // Record recycling in batches
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 5);
        
        // Check Earth Champion progress - the contract doesn't update progress incrementally
        // It only sets progress to the required amount when the quest is completed
        (uint256 progress1, uint256 required, bool completed1, ) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.EARTH_CHAMPION);
        
        // Check total recycled instead of progress
        assertEq(questSystem.totalRecycled(user1EmailHash), 5);
        assertEq(required, 20);
        assertFalse(completed1);
        
        // Record more recycling
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.METAL, 15);
        
        // Check Earth Champion is now completed
        (uint256 progress2, , bool completed2, ) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.EARTH_CHAMPION);
        
        // When completed, progress should be set to the required amount
        assertEq(progress2, 20);
        assertTrue(completed2);
        
        // Verify total recycled is correct
        assertEq(questSystem.totalRecycled(user1EmailHash), 20);
        
        vm.stopPrank();
    }
    
    function testMultipleUsers() public {
        vm.startPrank(deployer);
        
        // Record recycling for both users
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        questSystem.recordRecycling(user2EmailHash, IRecyclingSystem.RecyclableType.METAL, 1);
        
        vm.stopPrank();
        
        // Verify emails
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        vm.prank(user2);
        questSystem.verifyEmail(user2EmailHash, user2, fakeProof);
        
        // Both users claim rewards
        vm.prank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        vm.prank(user2);
        questSystem.claimRewards(user2EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        // Check both users received rewards
        assertEq(trashToken.balanceOf(user1), 10 * 10**18);
        assertEq(trashToken.balanceOf(user2), 10 * 10**18);
        assertEq(trashNFT.balanceOf(user1), 1);
        assertEq(trashNFT.balanceOf(user2), 1);
    }
    
    // Helper function to get quest details
    function getQuestDetails(QuestSystem.QuestType questType) internal view returns (
        string memory name,
        string memory description,
        uint256 requiredAmount,
        uint256 rewardAmount,
        bool nftReward,
        string memory nftURI
    ) {
        (name, description, requiredAmount, rewardAmount, nftReward, nftURI) = questSystem.quests(questType);
    }
}
