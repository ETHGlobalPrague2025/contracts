// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TrashToken.sol";
import "../src/TrashNFT.sol";
import "../src/QuestSystem.sol";
import { IRecyclingSystem } from "../src/RecyclingSystem.sol";
import "../src/TestUSDC.sol";

contract TrashSystemTest is Test {
    TrashToken public trashToken;
    TrashNFT public trashNFT;
    QuestSystem public questSystem;
    address public recyclingSystem;
    TestUSDC public usdc;

    address public deployer = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public collector = address(4);

    bytes32 public user1EmailHash = keccak256(abi.encodePacked("user1@example.com"));
    bytes32 public user2EmailHash = keccak256(abi.encodePacked("user2@example.com"));

    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy USDC
        usdc = new TestUSDC();
        
        // Deploy RecyclingSystem
        // We'll use a mock address for testing
        recyclingSystem = address(0x123);
        
        // Deploy TRASH token
        trashToken = new TrashToken();
        
        // Deploy TrashNFT
        trashNFT = new TrashNFT();
        
        // Deploy QuestSystem
        questSystem = new QuestSystem(
            address(trashToken),
            address(trashNFT),
            address(recyclingSystem)
        );
        
        // Transfer ownership of tokens to QuestSystem
        trashToken.transferOwnership(address(questSystem));
        trashNFT.transferOwnership(address(questSystem));
        
        vm.stopPrank();
    }

    function testTrashTokenMinting() public {
        // Only owner (QuestSystem) should be able to mint
        vm.startPrank(address(questSystem));
        trashToken.mint(user1, 100 * 10**18);
        vm.stopPrank();
        
        assertEq(trashToken.balanceOf(user1), 100 * 10**18);
        
        // Non-owner should not be able to mint
        vm.startPrank(user1);
        vm.expectRevert();
        trashToken.mint(user2, 100 * 10**18);
        vm.stopPrank();
    }

    function testTrashNFTMinting() public {
        // Only owner (QuestSystem) should be able to mint
        vm.startPrank(address(questSystem));
        uint256 tokenId = trashNFT.mintNFT(user1, 1, "ipfs://test");
        vm.stopPrank();
        
        assertEq(trashNFT.ownerOf(tokenId), user1);
        assertEq(trashNFT.getQuestId(tokenId), 1);
        
        // Non-owner should not be able to mint
        vm.startPrank(user1);
        vm.expectRevert();
        trashNFT.mintNFT(user2, 2, "ipfs://test2");
        vm.stopPrank();
    }

    function testQuestCompletion() public {
        // Setup: Record recycling for user1
        vm.startPrank(deployer);
        
        // Record recycling for First Recycler quest
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        
        // Verify quest completion
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(progress, 1);
        assertEq(required, 1);
        assertTrue(completed);
        assertFalse(claimed);
        
        vm.stopPrank();
    }

    function testEmailVerificationAndRewardClaim() public {
        // Setup: Complete a quest for user1
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        vm.stopPrank();
        
        // Verify email
        bytes memory fakeProof = abi.encodePacked("fake proof");
        vm.prank(user1);
        questSystem.verifyEmail(user1EmailHash, user1, fakeProof);
        
        // Claim rewards
        vm.prank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        // Verify rewards were received
        assertEq(trashToken.balanceOf(user1), 10 * 10**18); // 10 TRASH tokens
        assertEq(trashNFT.balanceOf(user1), 1); // 1 NFT
        
        // Verify quest is now claimed
        (, , , bool claimed) = questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        assertTrue(claimed);
        
        // Cannot claim again
        vm.expectRevert();
        vm.prank(user1);
        questSystem.claimRewards(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
    }

    function testWeeklyWarriorQuest() public {
        // Setup: Record recycling for Weekly Warrior quest
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 5);
        vm.stopPrank();
        
        // Verify quest completion
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.WEEKLY_WARRIOR);
        
        assertEq(progress, 5);
        assertEq(required, 5);
        assertTrue(completed);
        assertFalse(claimed);
    }

    function testEarthChampionQuest() public {
        // Setup: Record recycling for Earth Champion quest
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 20);
        vm.stopPrank();
        
        // Verify quest completion
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.EARTH_CHAMPION);
        
        assertEq(progress, 20);
        assertEq(required, 20);
        assertTrue(completed);
        assertFalse(claimed);
    }

    function testMaterialMasterQuest() public {
        // Setup: Record recycling for Material Master quest
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.METAL, 1);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.OTHER, 1);
        vm.stopPrank();
        
        // Verify quest completion
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.MATERIAL_MASTER);
        
        assertEq(progress, 3);
        assertEq(required, 3);
        assertTrue(completed);
        assertFalse(claimed);
    }

    function testQuestUpdate() public {
        // Update a quest
        vm.startPrank(deployer);
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
        
        // Record recycling (only 1 item, which is now not enough)
        vm.startPrank(deployer);
        questSystem.recordRecycling(user1EmailHash, IRecyclingSystem.RecyclableType.PLASTIC, 1);
        vm.stopPrank();
        
        // Verify quest is not completed
        (uint256 progress, uint256 required, bool completed, bool claimed) = 
            questSystem.getQuestStatus(user1EmailHash, QuestSystem.QuestType.FIRST_RECYCLER);
        
        assertEq(progress, 1);
        assertEq(required, 2);
        assertFalse(completed);
        assertFalse(claimed);
    }
}
