// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../utils/ContextMixin.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/NativeMetaTransaction.sol";
import "../utils/SybelRoles.sol";

// Error
/// @dev error throwned when the contract cap is exceeded
error CapExceed();

/**
 * Sybel token on the ethereum mainnet, simpler
 */
/// @custom:security-contact crypto-support@sybel.co
contract SybelTokenL1 is ERC20Upgradeable, SybelAccessControlUpgradeable, NativeMetaTransaction, ContextMixin {
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    uint256 private constant _cap = 3_000_000_000 ether; // 3 billion FRK

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

    function mint(address to, uint256 amount) public onlyRole(PREDICATE_ROLE) whenNotPaused {
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(to, amount);
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }
}
