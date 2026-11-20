// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";
import { MockVault } from "./MockVault.sol";

/// @title GuardianGuard — the destination-side guard (deployed on Base Sepolia).
/// @notice Receives the Reactive callback and rescues the vault position.
///         Two independent checks guard the rescue entry point:
///         onlyServiceProvider (the caller is the chain's callback proxy) and
///         onlyCallbackSender (the address the network injected into the
///         payload is our GuardianRSC on Lasna).
contract GuardianGuard is AbstractCallback {
    MockVault public immutable vault;

    event Rescued(address indexed reactive, address indexed position);

    constructor(IPayable callbackProxy_, address callbackSender_, address vault_)
        payable
        AbstractCallback(callbackProxy_, callbackSender_)
    {
        vault = MockVault(vault_);
    }

    /// @notice Settles any outstanding debt to the callback proxy from this
    ///         contract's balance (a contract in debt receives no callbacks).
    function coverDebt() external {
        _coverDebt();
    }

    /// @notice Called by the callback proxy when GuardianRSC requests a rescue.
    /// @param reactive_ Injected by the network: the requesting RSC's address.
    ///        Passed as address(0) in the payload; the first 160 bits are
    ///        overwritten in transit with the real sender.
    function rescue(address reactive_) external onlyServiceProvider onlyCallbackSender(reactive_) {
        address position = vault.positionOwner();
        vault.rescuePosition();
        emit Rescued(reactive_, position);
    }
}
