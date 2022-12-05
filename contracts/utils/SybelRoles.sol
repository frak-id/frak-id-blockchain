// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

library SybelRoles {
    // Administrator role of a contra
    bytes32 internal constant ADMIN = 0x00;

    // Role required to update a smart contract
    bytes32 internal constant UPGRADER = keccak256("UPGRADER_ROLE");

    // Role required to pause a smart contract
    bytes32 internal constant PAUSER = keccak256("PAUSER_ROLE");

    // Role required to mint new token on in a contract
    bytes32 internal constant MINTER = keccak256("MINTER_ROLE");

    // Role required to update the badge in a contract
    bytes32 internal constant BADGE_UPDATER = keccak256("BADGE_UPDATER_ROLE");

    // Role required to reward user for their listen
    bytes32 internal constant REWARDER = keccak256("REWARDER_ROLE");

    // Role required to perform token specific actions on a contract
    bytes32 internal constant TOKEN_CONTRACT = keccak256("TOKEN_ROLE");

    // Role required to manage the vesting wallets
    bytes32 internal constant VESTING_MANAGER = keccak256("VESTING_MANAGER");
    bytes32 internal constant VESTING_CREATOR = keccak256("VESTING_CREATOR");
}
