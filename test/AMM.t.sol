// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/Token.sol";

contract AMMTest is Test {
    AMM public amm;
    Token public tokenA;
    Token public tokenB;

    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);

    uint256 constant INITIAL_LIQUIDITY = 10_000 ether;
    uint256 constant SWAP_AMOUNT = 100 ether;

    function setUp() public {
        vm.startPrank(owner);
        tokenA = new Token("Token A", "TKA", owner);
        tokenB = new Token("Token B", "TKB", owner);
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(alice, 100_000 ether);
        tokenB.mint(alice, 100_000 ether);
        tokenA.mint(bob, 100_000 ether);
        tokenB.mint(bob, 100_000 ether);
    }

    function _addLiquidity(address user, uint256 amtA, uint256 amtB) internal {
        vm.startPrank(user);
        tokenA.approve(address(amm), amtA);
        tokenB.approve(address(amm), amtB);
        amm.addLiquidity(amtA, amtB);
        vm.stopPrank();
    }

    // --- ADD LIQUIDITY ---
    function test_AddLiquidity_First() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        assertEq(amm.reserveA(), INITIAL_LIQUIDITY);
        assertEq(amm.reserveB(), INITIAL_LIQUIDITY);
        assertGt(amm.lpToken().balanceOf(alice), 0);
    }

    function test_AddLiquidity_Subsequent() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        uint256 lpBefore = amm.lpToken().balanceOf(alice);
        _addLiquidity(alice, 10_000 ether, 10_000 ether);
        assertGt(amm.lpToken().balanceOf(alice), lpBefore);
    }

    function test_RevertAddLiquidity_ZeroAmount() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 ether);
        tokenB.approve(address(amm), 1000 ether);
        vm.expectRevert("Amounts must be > 0");
        amm.addLiquidity(0, 1000 ether);
        vm.stopPrank();
    }

    // --- REMOVE LIQUIDITY ---
    function test_RemoveLiquidity_Full() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        uint256 lp = amm.lpToken().balanceOf(alice);
        uint256 balABefore = tokenA.balanceOf(alice);

        vm.startPrank(alice);
        amm.removeLiquidity(lp);
        vm.stopPrank();

        assertGt(tokenA.balanceOf(alice), balABefore);
        assertEq(amm.lpToken().balanceOf(alice), 0);
    }

    function test_RemoveLiquidity_Partial() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        uint256 lp = amm.lpToken().balanceOf(alice);

        vm.startPrank(alice);
        amm.removeLiquidity(lp / 2);
        vm.stopPrank();

        assertGt(amm.lpToken().balanceOf(alice), 0);
        assertGt(amm.reserveA(), 0);
    }

    // --- SWAP ---
    function test_Swap_AtoB() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        uint256 balBefore = tokenB.balanceOf(bob);
        vm.startPrank(bob);
        tokenA.approve(address(amm), SWAP_AMOUNT);
        amm.swap(address(tokenA), SWAP_AMOUNT, 0);
        vm.stopPrank();

        assertGt(tokenB.balanceOf(bob), balBefore);
    }

    function test_Swap_BtoA() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        uint256 balBefore = tokenA.balanceOf(bob);
        vm.startPrank(bob);
        tokenB.approve(address(amm), SWAP_AMOUNT);
        amm.swap(address(tokenB), SWAP_AMOUNT, 0);
        vm.stopPrank();

        assertGt(tokenA.balanceOf(bob), balBefore);
    }

    function test_Swap_SlippageProtection() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);

        vm.startPrank(bob);
        tokenA.approve(address(amm), SWAP_AMOUNT);
        uint256 expectedOut = amm.getAmountOut(SWAP_AMOUNT, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.expectRevert("Slippage: insufficient output");
        amm.swap(address(tokenA), SWAP_AMOUNT, expectedOut + 1);
        vm.stopPrank();
    }

    function test_Swap_KInvariant() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), SWAP_AMOUNT);
        amm.swap(address(tokenA), SWAP_AMOUNT, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    function test_RevertSwap_InvalidToken() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.startPrank(bob);
        vm.expectRevert("Invalid token");
        amm.swap(address(0x999), SWAP_AMOUNT, 0);
        vm.stopPrank();
    }

    function test_RevertSwap_ZeroAmount() public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        vm.startPrank(bob);
        tokenA.approve(address(amm), SWAP_AMOUNT);
        vm.expectRevert("Amount must be > 0");
        amm.swap(address(tokenA), 0, 0);
        vm.stopPrank();
    }

    function test_GetAmountOut() public {
        uint256 out = amm.getAmountOut(1000 ether, 100_000 ether, 100_000 ether);
        assertGt(out, 0);
        assertLt(out, 1000 ether);
    }

    // --- FUZZ ---
    function testFuzz_Swap(uint256 amountIn) public {
        _addLiquidity(alice, INITIAL_LIQUIDITY, INITIAL_LIQUIDITY);
        amountIn = bound(amountIn, 1 ether, 10_000 ether);

        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        uint256 balBefore = tokenB.balanceOf(bob);
        amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        assertGt(tokenB.balanceOf(bob), balBefore);
    }
}