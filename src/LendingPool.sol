// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingPool {
    using SafeERC20 for IERC20;

    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant INTEREST_RATE_PER_SECOND = 317097919; // ~1% APR
    uint256 public constant LIQUIDATION_BONUS = 5;

    struct Position {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastUpdated;
    }

    mapping(address => Position) public positions;
    uint256 public collateralPrice = 1e18; // 1:1 по умолчанию

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address liquidator, uint256 amount);

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        positions[msg.sender].deposited += amount;
        positions[msg.sender].lastUpdated = block.timestamp;
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        uint256 maxBorrow = (pos.deposited * collateralPrice / 1e18) * LTV / 100;
        require(pos.borrowed + amount <= maxBorrow, "Exceeds LTV");

        pos.borrowed += amount;
        borrowToken.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        require(pos.borrowed > 0, "Nothing to repay");

        if (amount > pos.borrowed) amount = pos.borrowed;
        pos.borrowed -= amount;
        borrowToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Repaid(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        Position storage pos = positions[msg.sender];
        require(pos.deposited >= amount, "Insufficient deposit");

        uint256 newDeposit = pos.deposited - amount;
        if (pos.borrowed > 0) {
            uint256 maxBorrow = (newDeposit * collateralPrice / 1e18) * LTV / 100;
            require(pos.borrowed <= maxBorrow, "Health factor too low");
        }

        pos.deposited -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);

        Position storage pos = positions[user];
        require(pos.borrowed > 0, "Nothing to liquidate");

        uint256 maxBorrow = (pos.deposited * collateralPrice / 1e18) * LIQUIDATION_THRESHOLD / 100;
        require(pos.borrowed > maxBorrow, "Position is healthy");

        uint256 debtAmount = pos.borrowed;
        uint256 collateralToSeize = debtAmount * (100 + LIQUIDATION_BONUS) / 100;

        if (collateralToSeize > pos.deposited) {
            collateralToSeize = pos.deposited;
        }

        pos.borrowed = 0;
        pos.deposited -= collateralToSeize;

        borrowToken.safeTransferFrom(msg.sender, address(this), debtAmount);
        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(user, msg.sender, debtAmount);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.borrowed == 0) return type(uint256).max;
        uint256 collateralValue = pos.deposited * collateralPrice / 1e18;
        return (collateralValue * LIQUIDATION_THRESHOLD * 1e18) / (pos.borrowed * 100);
    }

    function setCollateralPrice(uint256 price) external {
        collateralPrice = price;
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.borrowed == 0 || pos.lastUpdated == 0) {
            pos.lastUpdated = block.timestamp;
            return;
        }
        uint256 timeElapsed = block.timestamp - pos.lastUpdated;
        uint256 interest = pos.borrowed * INTEREST_RATE_PER_SECOND * timeElapsed / 1e18;
        pos.borrowed += interest;
        pos.lastUpdated = block.timestamp;
    }
}