// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/Token.sol";

contract VaultTest is Test {
    Vault public vault;
    Token public asset;

    address public alice = address(2);
    address public bob = address(3);

    function setUp() public {
        asset = new Token("USD Coin", "USDC", address(this));
        vault = new Vault(IERC20(address(asset)), address(this));

        asset.mint(alice, 100_000 ether);
        asset.mint(bob, 100_000 ether);
        asset.mint(address(this), 100_000 ether);
    }

    // --- DEPOSIT ---
    function test_Deposit() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), 1000 ether);
    }

    function test_Deposit_ReceivesShares() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, alice);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.convertToAssets(shares), 1000 ether);
    }

    // --- WITHDRAW ---
    function test_Withdraw() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);
        vault.withdraw(500 ether, alice, alice);
        vm.stopPrank();

        assertEq(asset.balanceOf(alice), 99_500 ether);
        assertEq(vault.totalAssets(), 500 ether);
    }

    function test_Withdraw_Full() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);
        uint256 assets = vault.totalAssets();
        vault.withdraw(assets, alice, alice);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    // --- REDEEM ---
    function test_Redeem() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(assets, 1000 ether);
        assertEq(vault.balanceOf(alice), 0);
    }

    // --- HARVEST / SHARE PRICE ---
    function test_Harvest_IncreasesSharePrice() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);
        vm.stopPrank();

        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 assetsBefore = vault.convertToAssets(sharesBefore);

        // Owner добавляет yield
        asset.approve(address(vault), 500 ether);
        vault.harvest(500 ether);

        uint256 assetsAfter = vault.convertToAssets(sharesBefore);
        assertGt(assetsAfter, assetsBefore);
    }

    function test_Harvest_MultipleUsers() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, bob);
        vm.stopPrank();

        asset.approve(address(vault), 1000 ether);
        vault.harvest(1000 ether);

        // Оба получают пропорциональный yield
        assertGt(vault.convertToAssets(vault.balanceOf(alice)), 1000 ether);
        assertGt(vault.convertToAssets(vault.balanceOf(bob)), 1000 ether);
    }

    // --- CONVERT ---
    function test_ConvertToShares() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);
        vm.stopPrank();

        uint256 shares = vault.convertToShares(500 ether);
        assertGt(shares, 0);
    }

    function test_ConvertToAssets() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, alice);
        vm.stopPrank();

        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, 1000 ether);
    }

    // --- EDGE CASES ---
    function test_RevertDeposit_ZeroAmount() public {
    vm.startPrank(alice);
    asset.approve(address(vault), 1000 ether);
    uint256 shares = vault.deposit(0, alice);
    assertEq(shares, 0);
    vm.stopPrank();
}

    function test_MultipleDeposits_SharePriceConsistent() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 2000 ether);
        vault.deposit(1000 ether, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), 2000 ether);
        vault.deposit(1000 ether, bob);
        vm.stopPrank();

        assertEq(vault.convertToAssets(vault.balanceOf(alice)),
                 vault.convertToAssets(vault.balanceOf(bob)));
    }
}