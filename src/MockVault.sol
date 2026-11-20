// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { MockOracle } from "./MockOracle.sol";

/// @title MockVault — a mock leveraged position whose health tracks MockOracle's price.
/// @notice When the price falls below the safety threshold, anyone can call
///         checkHealth() and the vault emits Danger — the event the Reactive
///         contract on Lasna subscribes to. The position can only be rescued
///         (closed) by the authorized guard contract, which is the destination
///         of the Reactive callback.
contract MockVault {
    address public owner;
    MockOracle public immutable oracle;
    /// @notice Price below this level means the position is in danger.
    uint256 public immutable healthThreshold;
    /// @notice The only address allowed to rescue the position (GuardianGuard).
    address public guard;

    bool public positionOpen;
    address public positionOwner;
    uint256 public positionSize;

    event PositionOpened(address indexed owner, uint256 size);
    event Danger(address indexed position, uint256 price, uint256 health);
    event PositionRescued(address indexed position, uint256 price);

    constructor(address oracle_, uint256 healthThreshold_) {
        owner = msg.sender;
        oracle = MockOracle(oracle_);
        healthThreshold = healthThreshold_;
    }

    function setGuard(address guard_) external {
        require(msg.sender == owner, "MockVault: not owner");
        guard = guard_;
    }

    function openPosition(uint256 size_) external {
        require(msg.sender == owner, "MockVault: not owner");
        require(!positionOpen, "MockVault: already open");
        positionOpen = true;
        positionOwner = msg.sender;
        positionSize = size_;
        emit PositionOpened(msg.sender, size_);
    }

    /// @notice Health as a percentage of the threshold price (100 = exactly at threshold).
    function healthFactor() public view returns (uint256) {
        return (oracle.price() * 100) / healthThreshold;
    }

    /// @notice Emits Danger when the position's health is below the threshold.
    ///         This event is the origin trigger for the Reactive loop.
    function checkHealth() external {
        require(positionOpen, "MockVault: no open position");
        uint256 price = oracle.price();
        if (price < healthThreshold) {
            emit Danger(positionOwner, price, healthFactor());
        }
    }

    /// @notice Closes the position to safety. Callable only by the guard —
    ///         which itself only acts when the Reactive callback arrives.
    function rescuePosition() external {
        require(msg.sender == guard, "MockVault: only guard");
        require(positionOpen, "MockVault: no open position");
        positionOpen = false;
        emit PositionRescued(positionOwner, oracle.price());
    }
}
