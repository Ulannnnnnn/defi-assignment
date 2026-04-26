// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is ERC4626, Ownable {

    constructor(
        IERC20 asset,
        address initialOwner
    )
        ERC4626(asset)
        ERC20("Vault Share", "vSHARE")
        Ownable(initialOwner)
    {}

    // Симуляция yield — owner добавляет токены в vault
    // Это увеличивает цену шары для всех держателей
    function harvest(uint256 amount) external onlyOwner {
        IERC20(asset()).transferFrom(msg.sender, address(this), amount);
    }

    // ERC4626 автоматически реализует:
    // deposit(), withdraw(), mint(), redeem()
    // convertToShares(), convertToAssets()
    // previewDeposit(), previewWithdraw()
    // totalAssets()
}