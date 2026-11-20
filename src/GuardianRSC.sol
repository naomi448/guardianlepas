// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/// @title GuardianRSC — the Reactive Smart Contract (deployed on Lasna).
/// @notice Subscribes to MockVault's Danger event on Base Sepolia. When a
///         position is in danger, it requests a callback to GuardianGuard on
///         Base Sepolia, which rescues (closes) the position automatically —
///         "set it and forget it": the position owner does nothing.
///
/// @dev Deployment order matters: this contract is deployed BEFORE the guard,
///      because the guard's constructor needs this contract's address as its
///      immutable authorized callback sender. The guard's address is therefore
///      wired in afterwards via setGuard().
contract GuardianRSC is AbstractReactive {
    uint256 public immutable originChainId;
    address public immutable originContract;
    uint256 public immutable dangerTopic0;
    uint256 public immutable destinationChainId;

    address public owner;
    /// @notice The GuardianGuard contract on the destination chain.
    address public guard;
    uint64 public callbackGasLimit = 1_000_000;

    event GuardSet(address guard);
    event RescueRequested(uint256 indexed originTxHash, uint256 price);

    constructor(
        uint256 originChainId_,
        address originContract_,
        uint256 dangerTopic0_,
        uint256 destinationChainId_
    ) payable {
        originChainId = originChainId_;
        originContract = originContract_;
        dangerTopic0 = dangerTopic0_;
        destinationChainId = destinationChainId_;
        owner = msg.sender;
        SYSTEM.subscribe(
            originChainId_, originContract_, dangerTopic0_, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
    }

    function setGuard(address guard_) external {
        require(msg.sender == owner, "GuardianRSC: not owner");
        guard = guard_;
        emit GuardSet(guard_);
    }

    /// @notice Settles any outstanding debt to the system contract from this
    ///         contract's balance (a contract with debt stops receiving react()).
    function coverDebt() external {
        _coverDebt();
    }

    /// @inheritdoc IReactive
    function react(IReactive.LogRecord calldata log_) external onlySystem {
        // Route on topic0 only; non-matching logs fall through without
        // reverting (a reverting react() is still charged in full).
        if (log_.topic0 != dangerTopic0) return;
        if (guard == address(0)) return;

        uint256 price;
        if (log_.data.length >= 32) {
            price = abi.decode(log_.data, (uint256));
        }

        // The payload's first argument MUST be a dummy address(0): the network
        // overwrites the first 160 bits with this contract's address so the
        // destination can authenticate the callback sender.
        bytes memory payload = abi.encodeWithSignature("rescue(address)", address(0));
        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId, recipient: guard, gasLimit: callbackGasLimit, payload: payload
            })
        );
        emit RescueRequested(log_.txHash, price);
    }
}
