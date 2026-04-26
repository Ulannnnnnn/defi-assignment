// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract PriceFeedConsumer {
    AggregatorV3Interface public immutable priceFeed;
    uint256 public constant STALE_THRESHOLD = 1 hours;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (int256 price, uint8 decimals) {
        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
        ) = priceFeed.latestRoundData();

        require(answer > 0, "Invalid price");
        require(
            block.timestamp - updatedAt <= STALE_THRESHOLD,
            "Stale price data"
        );

        return (answer, priceFeed.decimals());
    }

    function getLatestPriceUSD() public view returns (uint256) {
        (int256 price, uint8 decimals) = getLatestPrice();
        return uint256(price) / (10 ** decimals);
    }
}