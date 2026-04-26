// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceFeedConsumer.sol";
import "../src/PriceDependentVault.sol";
import "../src/MockAggregator.sol";

contract PriceFeedTest is Test {
    PriceFeedConsumer public consumer;
    PriceDependentVault public vault;
    MockAggregator public mock;

    address public alice = address(2);
    address public bob = address(3);

    int256 constant ETH_PRICE = 2000 * 1e8; // $2000 с 8 decimals
    uint256 constant THRESHOLD = 1500;       // $1500 порог вывода

    function setUp() public {
        mock = new MockAggregator(ETH_PRICE, 8);
        consumer = new PriceFeedConsumer(address(mock));
        vault = new PriceDependentVault(address(mock), THRESHOLD);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // --- PRICE FEED ---
    function test_GetLatestPrice() public view {
        (int256 price, uint8 decimals) = consumer.getLatestPrice();
        assertEq(price, ETH_PRICE);
        assertEq(decimals, 8);
    }

    function test_GetLatestPriceUSD() public view {
        uint256 price = consumer.getLatestPriceUSD();
        assertEq(price, 2000);
    }

    function test_PriceUpdate() public {
        mock.setPrice(3000 * 1e8);
        uint256 price = consumer.getLatestPriceUSD();
        assertEq(price, 3000);
    }

    function test_RevertStalePrice() public {
        // Перематываем время на 2 часа вперёд
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert("Stale price data");
        consumer.getLatestPrice();
    }

    function test_RevertInvalidPrice() public {
        mock.setPrice(-1);
        vm.expectRevert("Invalid price");
        consumer.getLatestPrice();
    }

    // --- VAULT ---
    function test_Deposit() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        assertEq(vault.deposits(alice), 1 ether);
        assertEq(vault.totalDeposits(), 1 ether);
    }

    function test_Withdraw_AboveThreshold() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        // Цена выше порога — вывод разрешён
        uint256 balBefore = alice.balance;
        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(alice.balance, balBefore + 1 ether);
        assertEq(vault.deposits(alice), 0);
    }

    function test_RevertWithdraw_BelowThreshold() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        // Цена падает ниже порога
        mock.setPrice(1000 * 1e8);

        vm.prank(alice);
        vm.expectRevert("ETH price below threshold");
        vault.withdraw(1 ether);
    }

    function test_RevertWithdraw_InsufficientBalance() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        vault.withdraw(2 ether);
    }

    function test_GetUSDValue() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        uint256 usdValue = vault.getUSDValue(alice);
        assertEq(usdValue, 2000);
    }

    function test_MultipleUsers() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.prank(bob);
        vault.deposit{value: 3 ether}();

        assertEq(vault.totalDeposits(), 5 ether);
        assertEq(vault.deposits(alice), 2 ether);
        assertEq(vault.deposits(bob), 3 ether);
    }

    function test_RevertDeposit_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be > 0");
        vault.deposit{value: 0}();
    }
}