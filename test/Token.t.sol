// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);

    function setUp() public {
        vm.prank(owner);
        token = new Token("MyToken", "MTK", owner);
    }

    // --- MINT ---
    function test_MintTokens() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_MintIncreasesTotalSupply() public {
        vm.prank(owner);
        token.mint(alice, 500 ether);
        assertEq(token.totalSupply(), 500 ether);
    }

    function test_RevertMint_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }

    function test_RevertMint_ExceedsMaxSupply() public {
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        token.mint(alice, 2_000_000 * 10 ** 18);
    }

    // --- TRANSFER ---
    function test_Transfer() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.transfer(bob, 400 ether);
        assertEq(token.balanceOf(alice), 600 ether);
        assertEq(token.balanceOf(bob), 400 ether);
    }

    function test_RevertTransfer_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 100 ether);
    }

    // --- APPROVE & TRANSFERFROM ---
    function test_Approve() public {
        vm.prank(alice);
        token.approve(bob, 500 ether);
        assertEq(token.allowance(alice, bob), 500 ether);
    }

    function test_TransferFrom() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 500 ether);
        vm.prank(bob);
        token.transferFrom(alice, bob, 300 ether);
        assertEq(token.balanceOf(alice), 700 ether);
        assertEq(token.balanceOf(bob), 300 ether);
        assertEq(token.allowance(alice, bob), 200 ether);
    }

    function test_RevertTransferFrom_ExceedsAllowance() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 500 ether);
    }

    // --- BURN ---
    function test_Burn() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.burn(400 ether);
        assertEq(token.balanceOf(alice), 600 ether);
        assertEq(token.totalSupply(), 600 ether);
    }

    // --- FUZZ ---
    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 10 ** 18);
        vm.prank(owner);
        token.mint(alice, amount);
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
    }

    // --- INVARIANT SETUP ---
    function invariant_TotalSupplyNeverExceedsMax() public view {
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }

    function invariant_BalanceNeverExceedsSupply() public view {
        assertLe(token.balanceOf(alice), token.totalSupply());
        assertLe(token.balanceOf(bob), token.totalSupply());
    }
}