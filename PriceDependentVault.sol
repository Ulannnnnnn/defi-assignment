// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PriceFeedConsumer.sol";

contract PriceDependentVault is PriceFeedConsumer {
    uint256 public withdrawThreshold;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _priceFeed, uint256 _withdrawThreshold)
        PriceFeedConsumer(_priceFeed)
    {
        withdrawThreshold = _withdrawThreshold;
    }

    function deposit() external payable {
        require(msg.value > 0, "Amount must be > 0");
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        uint256 currentPrice = getLatestPriceUSD();
        require(
            currentPrice >= withdrawThreshold,
            "ETH price below threshold"
        );

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function getUSDValue(address user) external view returns (uint256) {
        (int256 price, uint8 decimals) = getLatestPrice();
        return deposits[user] * uint256(price) / (10 ** decimals) / 1e18;
    }
}