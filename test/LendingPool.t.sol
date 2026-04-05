// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/Token.sol";

contract LendingPoolTest is Test {
    LendingPool public pool;
    Token public collateral;
    Token public borrowToken;

    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);
    address public liquidator = address(4);

    uint256 constant DEPOSIT_AMOUNT = 10_000 ether;
    uint256 constant BORROW_AMOUNT = 7_000 ether;

    function setUp() public {
        vm.startPrank(owner);
        collateral = new Token("Collateral", "COL", owner);
        borrowToken = new Token("Borrow Token", "BRW", owner);
        pool = new LendingPool(address(collateral), address(borrowToken));

        collateral.mint(alice, 100_000 ether);
        collateral.mint(liquidator, 100_000 ether);
        borrowToken.mint(address(pool), 100_000 ether);
        borrowToken.mint(alice, 50_000 ether);
        borrowToken.mint(liquidator, 50_000 ether);
        vm.stopPrank();
    }

    // --- DEPOSIT ---
    function test_Deposit() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, DEPOSIT_AMOUNT);
    }

    function test_RevertDeposit_ZeroAmount() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        vm.expectRevert("Amount must be > 0");
        pool.deposit(0);
        vm.stopPrank();
    }

    // --- BORROW ---
    function test_Borrow_WithinLTV() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        vm.stopPrank();

        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, BORROW_AMOUNT);
    }

    function test_RevertBorrow_ExceedsLTV() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(8_000 ether);
        vm.stopPrank();
    }

    function test_RevertBorrow_ZeroCollateral() public {
        vm.startPrank(alice);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(1000 ether);
        vm.stopPrank();
    }

    // --- REPAY ---
    function test_Repay_Full() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        borrowToken.approve(address(pool), BORROW_AMOUNT);
        pool.repay(BORROW_AMOUNT);
        vm.stopPrank();

        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, 0);
    }

    function test_Repay_Partial() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        borrowToken.approve(address(pool), 3_000 ether);
        pool.repay(3_000 ether);
        vm.stopPrank();

        (, uint256 borrowed,) = pool.positions(alice);
        assertLt(borrowed, BORROW_AMOUNT);
    }

    // --- WITHDRAW ---
    function test_Withdraw_AfterRepay() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        borrowToken.approve(address(pool), BORROW_AMOUNT);
        pool.repay(BORROW_AMOUNT);
        pool.withdraw(DEPOSIT_AMOUNT);
        vm.stopPrank();

        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, 0);
    }

    function test_RevertWithdraw_WithDebt() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        vm.expectRevert("Health factor too low");
        pool.withdraw(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    // --- LIQUIDATION ---
    function test_Liquidation() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        vm.stopPrank();

        // Цена залога падает — позиция становится ликвидируемой
        pool.setCollateralPrice(0.8e18);

        uint256 liquidatorBalBefore = collateral.balanceOf(liquidator);

        vm.startPrank(liquidator);
        borrowToken.approve(address(pool), BORROW_AMOUNT);
        pool.liquidate(alice);
        vm.stopPrank();

        assertGt(collateral.balanceOf(liquidator), liquidatorBalBefore);
        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, 0);
    }

    // --- INTEREST ---
    function test_InterestAccrual() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        vm.stopPrank();

        (, uint256 borrowedBefore,) = pool.positions(alice);

        // Перематываем время на 1 год
        vm.warp(block.timestamp + 365 days);

        // Триггерим начисление процентов через repay
        vm.startPrank(alice);
        borrowToken.approve(address(pool), 1);
        pool.repay(1);
        vm.stopPrank();

        (, uint256 borrowedAfter,) = pool.positions(alice);
        assertGt(borrowedAfter, borrowedBefore);
    }

    // --- HEALTH FACTOR ---
    function test_HealthFactor() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), DEPOSIT_AMOUNT);
        pool.deposit(DEPOSIT_AMOUNT);
        pool.borrow(BORROW_AMOUNT);
        vm.stopPrank();

        uint256 hf = pool.getHealthFactor(alice);
        assertGt(hf, 1e18);
    }
}