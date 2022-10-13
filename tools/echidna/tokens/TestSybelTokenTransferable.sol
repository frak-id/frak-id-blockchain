// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./PropertiesSybelTokenTransferable.sol";

contract TestSybelTokenTransferable is PropertiesSybelTokenTransferable {
    constructor() public {
        // Existing addresses:
        // - crytic_owner: If the contract has an owner, it must be crytic_owner
        // - crytic_user: Legitimate user
        // - crytic_attacker: Attacker
        //
        // Add below a minimal configuration:
        // - crytic_owner must have some tokens
        // - crytic_user must have some tokens
        // - crytic_attacker must have some tokens
        _mint(crytic_owner, 1 ether);
        _mint(crytic_user, 1 ether);
        _mint(crytic_attacker, 1 ether);

        //
        //
        // Update the following if totalSupply and balanceOf are external functions or state variables:

        initialTotalSupply = totalSupply();
        initialBalance_owner = balanceOf(crytic_owner);
        initialBalance_user = balanceOf(crytic_user);
        initialBalance_attacker = balanceOf(crytic_attacker);
    }
}
