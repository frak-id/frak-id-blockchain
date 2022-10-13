// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../utils/ContextMixin.sol";
import "../utils/NativeMetaTransaction.sol";
import "../utils/SybelRoles.sol";

/**
 * Sybel token on the ethereum mainnet, simpler
 */
/// @custom:security-contact crypto-support@sybel.co
contract SybelTokenL1 is ERC20, ERC20Burnable, Pausable, AccessControl, NativeMetaTransaction, ContextMixin {
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    uint256 private _cap;

    constructor() ERC20("Sybel Token", "SYBL") {
        _grantRole(SybelRoles.ADMIN, _msgSender());
        _grantRole(SybelRoles.PAUSER, _msgSender());
        _grantRole(PREDICATE_ROLE, _msgSender());
        _initializeEIP712("Sybel Token");
    }

    function pause() public onlyRole(SybelRoles.PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(SybelRoles.PAUSER) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(PREDICATE_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }    
    
    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

}