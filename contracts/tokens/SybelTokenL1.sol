// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../utils/ContextMixin.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/NativeMetaTransaction.sol";
import "../utils/SybelRoles.sol";

/**
 * Sybel token on the ethereum mainnet, simpler
 */
/// @custom:security-contact crypto-support@sybel.co
contract SybelTokenL1 is ERC20Upgradeable, SybelAccessControlUpgradeable, NativeMetaTransaction, ContextMixin {
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    uint256 private _cap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        string memory name = "Frak";
        __ERC20_init(name, "FRK");
        _initializeEIP712(name);
        __SybelAccessControlUpgradeable_init();

        _grantRole(PREDICATE_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public onlyRole(PREDICATE_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }
}
