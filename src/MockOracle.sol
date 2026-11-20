// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title MockOracle — a deliberately simple price oracle for the GuardianLepas demo.
/// @notice The owner sets a price; MockVault reads it to judge position health.
///         In a production design this would be a real feed (e.g. Chainlink);
///         here it exists so the danger scenario is reproducible on demand.
contract MockOracle {
    address public owner;
    uint256 public price;

    event PriceUpdated(uint256 price);

    constructor(uint256 initialPrice_) {
        owner = msg.sender;
        price = initialPrice_;
    }

    function setPrice(uint256 price_) external {
        require(msg.sender == owner, "MockOracle: not owner");
        price = price_;
        emit PriceUpdated(price_);
    }
}
