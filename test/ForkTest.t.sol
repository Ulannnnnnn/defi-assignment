// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
    }

    // Тест 1: читаем реальный totalSupply USDC
    function test_USDC_TotalSupply() public {
        uint256 supply = IERC20(USDC).totalSupply();
        console.log("USDC Total Supply:", supply);
        assertGt(supply, 0, "USDC supply should be > 0");
    }

    // Тест 2: проверяем баланс крупного холдера USDC
    function test_USDC_WhaleBalance() public {
        address whale = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
        uint256 balance = IERC20(USDC).balanceOf(whale);
        console.log("Whale USDC balance:", balance);
        assertGt(balance, 0);
    }

    // Тест 3: симулируем swap WETH -> USDC через Uniswap V2
    function test_UniswapV2_Swap() public {
        address trader = makeAddr("trader");
        uint256 wethAmount = 1 ether;

        // Даём трейдеру WETH
        deal(trader, wethAmount);
        vm.startPrank(trader);

        // Оборачиваем ETH в WETH
        (bool success,) = WETH.call{value: wethAmount}("");
        require(success, "WETH wrap failed");

        // Апрувим роутер
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, wethAmount);

        // Путь свапа: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        // Получаем ожидаемый output
        uint256[] memory amountsOut = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(wethAmount, path);
        console.log("Expected USDC out:", amountsOut[1]);

        // Выполняем своп
        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                wethAmount,
                amountsOut[1] * 95 / 100, // 5% slippage
                path,
                trader,
                block.timestamp + 300
            );

        console.log("Actual USDC received:", amounts[1]);
        assertGt(amounts[1], 0, "Should receive USDC");
        vm.stopPrank();
    }

    // Тест 4: vm.rollFork — переходим на конкретный блок
    function test_RollFork() public {
        uint256 blockNumber = 19_000_000;
        vm.rollFork(blockNumber);
        assertEq(block.number, blockNumber);
        console.log("Rolled to block:", block.number);

        uint256 supply = IERC20(USDC).totalSupply();
        console.log("USDC supply at block 19000000:", supply);
        assertGt(supply, 0);
    }
}