// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TrashToken.sol";

contract TrashTokenTest is Test {
    TrashToken public trashToken;
    
    address public deployer = address(1);
    address public owner = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    
    uint256 public constant MINT_AMOUNT = 100 * 10**18; // 100 TRASH tokens
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy TrashToken
        trashToken = new TrashToken();
        
        // Transfer ownership to owner
        trashToken.transferOwnership(owner);
        
        vm.stopPrank();
    }
    
    function testInitialState() public {
        // Check token name and symbol
        assertEq(trashToken.name(), "TRASH");
        assertEq(trashToken.symbol(), "TRASH");
        
        // Check initial supply is 0
        assertEq(trashToken.totalSupply(), 0);
        
        // Check owner is set correctly
        assertEq(trashToken.owner(), owner);
    }
    
    function testMintAsOwner() public {
        vm.startPrank(owner);
        
        // Mint tokens to user1
        trashToken.mint(user1, MINT_AMOUNT);
        
        vm.stopPrank();
        
        // Check user1 balance
        assertEq(trashToken.balanceOf(user1), MINT_AMOUNT);
        
        // Check total supply
        assertEq(trashToken.totalSupply(), MINT_AMOUNT);
    }
    
    function test_RevertWhen_MintAsNonOwner() public {
        vm.startPrank(user1);
        
        // This should fail because user1 is not the owner
        vm.expectRevert();
        trashToken.mint(user2, MINT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testTransferTokens() public {
        // First mint tokens to user1
        vm.prank(owner);
        trashToken.mint(user1, MINT_AMOUNT);
        
        // User1 transfers tokens to user2
        vm.startPrank(user1);
        trashToken.transfer(user2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Check balances
        assertEq(trashToken.balanceOf(user1), MINT_AMOUNT / 2);
        assertEq(trashToken.balanceOf(user2), MINT_AMOUNT / 2);
    }
    
    function test_RevertWhen_TransferMoreThanBalance() public {
        // First mint tokens to user1
        vm.prank(owner);
        trashToken.mint(user1, MINT_AMOUNT);
        
        // User1 tries to transfer more tokens than they have
        vm.startPrank(user1);
        vm.expectRevert();
        trashToken.transfer(user2, MINT_AMOUNT * 2);
        vm.stopPrank();
    }
    
    function testApproveAndTransferFrom() public {
        // First mint tokens to user1
        vm.prank(owner);
        trashToken.mint(user1, MINT_AMOUNT);
        
        // User1 approves user2 to spend tokens
        vm.startPrank(user1);
        trashToken.approve(user2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Check allowance
        assertEq(trashToken.allowance(user1, user2), MINT_AMOUNT / 2);
        
        // User2 transfers tokens from user1 to themselves
        vm.startPrank(user2);
        trashToken.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Check balances
        assertEq(trashToken.balanceOf(user1), MINT_AMOUNT / 2);
        assertEq(trashToken.balanceOf(user2), MINT_AMOUNT / 2);
        
        // Check allowance is now 0
        assertEq(trashToken.allowance(user1, user2), 0);
    }
    
    function test_RevertWhen_TransferFromMoreThanAllowance() public {
        // First mint tokens to user1
        vm.prank(owner);
        trashToken.mint(user1, MINT_AMOUNT);
        
        // User1 approves user2 to spend tokens
        vm.startPrank(user1);
        trashToken.approve(user2, MINT_AMOUNT / 4);
        vm.stopPrank();
        
        // User2 tries to transfer more tokens than allowed
        vm.startPrank(user2);
        vm.expectRevert();
        trashToken.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
    }
    
    function testTransferOwnership() public {
        vm.startPrank(owner);
        
        // Transfer ownership to user1
        trashToken.transferOwnership(user1);
        
        vm.stopPrank();
        
        // Check new owner
        assertEq(trashToken.owner(), user1);
        
        // New owner should be able to mint
        vm.startPrank(user1);
        trashToken.mint(user2, MINT_AMOUNT);
        vm.stopPrank();
        
        // Check user2 balance
        assertEq(trashToken.balanceOf(user2), MINT_AMOUNT);
    }
    
    function test_RevertWhen_TransferOwnershipAsNonOwner() public {
        vm.startPrank(user1);
        
        // This should fail because user1 is not the owner
        vm.expectRevert();
        trashToken.transferOwnership(user2);
        
        vm.stopPrank();
    }
    
    function testRenounceOwnership() public {
        vm.startPrank(owner);
        
        // Renounce ownership
        trashToken.renounceOwnership();
        
        vm.stopPrank();
        
        // Check owner is now address(0)
        assertEq(trashToken.owner(), address(0));
    }
    
    function test_RevertWhen_MintAfterRenouncingOwnership() public {
        vm.startPrank(owner);
        
        // Renounce ownership
        trashToken.renounceOwnership();
        
        // Try to mint (should fail)
        vm.expectRevert();
        trashToken.mint(user1, MINT_AMOUNT);
        
        vm.stopPrank();
    }
}
