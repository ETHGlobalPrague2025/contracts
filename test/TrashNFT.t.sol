// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TrashNFT.sol";

contract TrashNFTTest is Test {
    TrashNFT public trashNFT;
    
    address public deployer = address(1);
    address public owner = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    
    uint256 public constant QUEST_ID_1 = 1;
    uint256 public constant QUEST_ID_2 = 2;
    string public constant TOKEN_URI_1 = "ipfs://QmTest1";
    string public constant TOKEN_URI_2 = "ipfs://QmTest2";
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy TrashNFT
        trashNFT = new TrashNFT();
        
        // Transfer ownership to owner
        trashNFT.transferOwnership(owner);
        
        vm.stopPrank();
    }
    
    function testInitialState() public {
        // Check token name and symbol
        assertEq(trashNFT.name(), "TrashNFT");
        assertEq(trashNFT.symbol(), "TNFT");
        
        // Check owner is set correctly
        assertEq(trashNFT.owner(), owner);
    }
    
    function testMintNFTAsOwner() public {
        vm.startPrank(owner);
        
        // Mint NFT to user1
        uint256 tokenId = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        
        vm.stopPrank();
        
        // Check token ownership
        assertEq(trashNFT.ownerOf(tokenId), user1);
        
        // Check token URI
        assertEq(trashNFT.tokenURI(tokenId), TOKEN_URI_1);
        
        // Check quest ID
        assertEq(trashNFT.getQuestId(tokenId), QUEST_ID_1);
        
        // Check token ID is 0 (first token)
        assertEq(tokenId, 0);
    }
    
    function test_RevertWhen_MintNFTAsNonOwner() public {
        vm.startPrank(user1);
        
        // This should fail because user1 is not the owner
        vm.expectRevert();
        trashNFT.mintNFT(user2, QUEST_ID_1, TOKEN_URI_1);
        
        vm.stopPrank();
    }
    
    function testMintMultipleNFTs() public {
        vm.startPrank(owner);
        
        // Mint first NFT to user1
        uint256 tokenId1 = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        
        // Mint second NFT to user2
        uint256 tokenId2 = trashNFT.mintNFT(user2, QUEST_ID_2, TOKEN_URI_2);
        
        vm.stopPrank();
        
        // Check token ownerships
        assertEq(trashNFT.ownerOf(tokenId1), user1);
        assertEq(trashNFT.ownerOf(tokenId2), user2);
        
        // Check token URIs
        assertEq(trashNFT.tokenURI(tokenId1), TOKEN_URI_1);
        assertEq(trashNFT.tokenURI(tokenId2), TOKEN_URI_2);
        
        // Check quest IDs
        assertEq(trashNFT.getQuestId(tokenId1), QUEST_ID_1);
        assertEq(trashNFT.getQuestId(tokenId2), QUEST_ID_2);
        
        // Check token IDs are sequential
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
    }
    
    function testTransferNFT() public {
        // First mint NFT to user1
        vm.startPrank(owner);
        uint256 tokenId = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        vm.stopPrank();
        
        // User1 transfers NFT to user2
        vm.startPrank(user1);
        trashNFT.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
        
        // Check new ownership
        assertEq(trashNFT.ownerOf(tokenId), user2);
        
        // Quest ID should remain the same
        assertEq(trashNFT.getQuestId(tokenId), QUEST_ID_1);
    }
    
    function test_RevertWhen_TransferUnownedNFT() public {
        // First mint NFT to user1
        vm.startPrank(owner);
        uint256 tokenId = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        vm.stopPrank();
        
        // User2 tries to transfer NFT they don't own
        vm.startPrank(user2);
        vm.expectRevert();
        trashNFT.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
    }
    
    function testApproveAndTransferNFT() public {
        // First mint NFT to user1
        vm.startPrank(owner);
        uint256 tokenId = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        vm.stopPrank();
        
        // User1 approves user2 to transfer the NFT
        vm.startPrank(user1);
        trashNFT.approve(user2, tokenId);
        vm.stopPrank();
        
        // Check approval
        assertEq(trashNFT.getApproved(tokenId), user2);
        
        // User2 transfers the NFT to themselves
        vm.startPrank(user2);
        trashNFT.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
        
        // Check new ownership
        assertEq(trashNFT.ownerOf(tokenId), user2);
    }
    
    function testSetApprovalForAll() public {
        // First mint multiple NFTs to user1
        vm.startPrank(owner);
        uint256 tokenId1 = trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        uint256 tokenId2 = trashNFT.mintNFT(user1, QUEST_ID_2, TOKEN_URI_2);
        vm.stopPrank();
        
        // User1 approves user2 for all tokens
        vm.startPrank(user1);
        trashNFT.setApprovalForAll(user2, true);
        vm.stopPrank();
        
        // Check approval for all
        assertTrue(trashNFT.isApprovedForAll(user1, user2));
        
        // User2 transfers both NFTs to themselves
        vm.startPrank(user2);
        trashNFT.transferFrom(user1, user2, tokenId1);
        trashNFT.transferFrom(user1, user2, tokenId2);
        vm.stopPrank();
        
        // Check new ownerships
        assertEq(trashNFT.ownerOf(tokenId1), user2);
        assertEq(trashNFT.ownerOf(tokenId2), user2);
    }
    
    function test_RevertWhen_GetQuestIdForNonexistentToken() public {
        // Try to get quest ID for a token that doesn't exist
        vm.expectRevert();
        trashNFT.getQuestId(999);
    }
    
    function testTransferOwnership() public {
        vm.startPrank(owner);
        
        // Transfer ownership to user1
        trashNFT.transferOwnership(user1);
        
        vm.stopPrank();
        
        // Check new owner
        assertEq(trashNFT.owner(), user1);
        
        // New owner should be able to mint
        vm.startPrank(user1);
        uint256 tokenId = trashNFT.mintNFT(user2, QUEST_ID_1, TOKEN_URI_1);
        vm.stopPrank();
        
        // Check token was minted
        assertEq(trashNFT.ownerOf(tokenId), user2);
    }
    
    function test_RevertWhen_TransferOwnershipAsNonOwner() public {
        vm.startPrank(user1);
        
        // This should fail because user1 is not the owner
        vm.expectRevert();
        trashNFT.transferOwnership(user2);
        
        vm.stopPrank();
    }
    
    function testRenounceOwnership() public {
        vm.startPrank(owner);
        
        // Renounce ownership
        trashNFT.renounceOwnership();
        
        vm.stopPrank();
        
        // Check owner is now address(0)
        assertEq(trashNFT.owner(), address(0));
    }
    
    function test_RevertWhen_MintAfterRenouncingOwnership() public {
        vm.startPrank(owner);
        
        // Renounce ownership
        trashNFT.renounceOwnership();
        
        // Try to mint (should fail)
        vm.expectRevert();
        trashNFT.mintNFT(user1, QUEST_ID_1, TOKEN_URI_1);
        
        vm.stopPrank();
    }
    
    function testSupportsInterface() public {
        // Check ERC721 interface
        assertTrue(trashNFT.supportsInterface(0x80ac58cd));
        
        // Check ERC721Metadata interface
        assertTrue(trashNFT.supportsInterface(0x5b5e139f));
        
        // Check ERC165 interface
        assertTrue(trashNFT.supportsInterface(0x01ffc9a7));
    }
}
