// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

// Access control error (when accessing unauthorized method, or renouncing role that he havn't go)
error RenounceForCallerOnly();
error NotAuthorized();

// Generic error used for all the contract
error InvalidArray();
error InvalidAddress();
error NoReward();
error RewardTooLarge();
error BadgeTooLarge();
error InvalidFraktionType();

/// @dev error throwned when the signer is invalid
error InvalidSigner();
/// @dev error throwned when the permit delay is expired
error PermitDelayExpired();
