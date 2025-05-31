// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TestUSDC.sol";

contract TestUSDCTest is Test {
    TestUSDC public usdc;
    
    address public user1 = address(1);
    address public user2 = address(2);
    
    uint256 public constant MINT_AMOUNT = 1000 * 10**6; // 1,000 USDC (6 decimals)
    
    function setUp() public {
        // Deploy TestUSDC
        usdc = new TestUSDC();
    }
    
    function testInitialState() public {
        // Check token name and symbol
        assertEq(usdc.name(), "Test USDC");
        assertEq(usdc.symbol(), "tUSDC");
        assertEq(usdc.decimals(), 6);
        
        // Check initial supply is 0
        assertEq(usdc.totalSupply(), 0);
    }
    
    function testMint() public {
        vm.startPrank(user1);
        
        // Mint tokens
        usdc.mint(MINT_AMOUNT);
        
        vm.stopPrank();
        
        // Check balance
        assertEq(usdc.balanceOf(user1), MINT_AMOUNT);
        
        // Check total supply
        assertEq(usdc.totalSupply(), MINT_AMOUNT);
    }
    
    function testTransfer() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Transfer tokens to user2
        usdc.transfer(user2, MINT_AMOUNT / 2);
        
        vm.stopPrank();
        
        // Check balances
        assertEq(usdc.balanceOf(user1), MINT_AMOUNT / 2);
        assertEq(usdc.balanceOf(user2), MINT_AMOUNT / 2);
    }
    
    function test_RevertWhen_TransferMoreThanBalance() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Try to transfer more tokens than user1 has
        vm.expectRevert();
        usdc.transfer(user2, MINT_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function test_RevertWhen_TransferToZeroAddress() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Try to transfer to zero address
        vm.expectRevert();
        usdc.transfer(address(0), MINT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    function testApproveAndTransferFrom() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Approve user2 to spend tokens
        usdc.approve(user2, MINT_AMOUNT / 2);
        
        vm.stopPrank();
        
        // Check allowance
        assertEq(usdc.allowance(user1, user2), MINT_AMOUNT / 2);
        
        // User2 transfers tokens from user1 to themselves
        vm.startPrank(user2);
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Check balances
        assertEq(usdc.balanceOf(user1), MINT_AMOUNT / 2);
        assertEq(usdc.balanceOf(user2), MINT_AMOUNT / 2);
        
        // Check allowance is now 0
        assertEq(usdc.allowance(user1, user2), 0);
    }
    
    function test_RevertWhen_TransferFromMoreThanAllowance() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Approve user2 to spend tokens
        usdc.approve(user2, MINT_AMOUNT / 4);
        
        vm.stopPrank();
        
        // User2 tries to transfer more tokens than allowed
        vm.startPrank(user2);
        vm.expectRevert();
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
    }
    
    function test_RevertWhen_TransferFromUnauthorized() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        vm.stopPrank();
        
        // User2 tries to transfer tokens without approval
        vm.startPrank(user2);
        vm.expectRevert();
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
    }
    
    function testInfiniteApproval() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Approve user2 to spend max uint256 tokens
        usdc.approve(user2, type(uint256).max);
        
        vm.stopPrank();
        
        // User2 transfers tokens multiple times
        vm.startPrank(user2);
        
        // First transfer
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 4);
        
        // Check allowance is still max
        assertEq(usdc.allowance(user1, user2), type(uint256).max);
        
        // Second transfer
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 4);
        
        // Check allowance is still max
        assertEq(usdc.allowance(user1, user2), type(uint256).max);
        
        vm.stopPrank();
        
        // Check balances
        assertEq(usdc.balanceOf(user1), MINT_AMOUNT / 2);
        assertEq(usdc.balanceOf(user2), MINT_AMOUNT / 2);
    }
    
    function testMultipleMints() public {
        // User1 mints tokens
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        vm.stopPrank();
        
        // User2 mints tokens
        vm.startPrank(user2);
        usdc.mint(MINT_AMOUNT * 2);
        vm.stopPrank();
        
        // Check balances
        assertEq(usdc.balanceOf(user1), MINT_AMOUNT);
        assertEq(usdc.balanceOf(user2), MINT_AMOUNT * 2);
        
        // Check total supply
        assertEq(usdc.totalSupply(), MINT_AMOUNT * 3);
    }
    
    function testApproveAndRevoke() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Approve user2 to spend tokens
        usdc.approve(user2, MINT_AMOUNT / 2);
        
        // Check allowance
        assertEq(usdc.allowance(user1, user2), MINT_AMOUNT / 2);
        
        // Revoke approval
        usdc.approve(user2, 0);
        
        vm.stopPrank();
        
        // Check allowance is now 0
        assertEq(usdc.allowance(user1, user2), 0);
        
        // User2 tries to transfer tokens
        vm.startPrank(user2);
        vm.expectRevert();
        usdc.transferFrom(user1, user2, MINT_AMOUNT / 2);
        vm.stopPrank();
    }
    
    function testTransferEvents() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        
        // Check for Transfer event during mint
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, MINT_AMOUNT);
        usdc.mint(MINT_AMOUNT);
        
        // Check for Transfer event during transfer
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, MINT_AMOUNT / 2);
        usdc.transfer(user2, MINT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    function testApprovalEvents() public {
        // First mint tokens to user1
        vm.startPrank(user1);
        usdc.mint(MINT_AMOUNT);
        
        // Check for Approval event
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, MINT_AMOUNT / 2);
        usdc.approve(user2, MINT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    // Events for testing
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
