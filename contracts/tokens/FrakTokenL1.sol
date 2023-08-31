// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { ERC20Upgradeable } from "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { FrakRoles } from "../utils/FrakRoles.sol";
import { FrakAccessControlUpgradeable } from "../utils/FrakAccessControlUpgradeable.sol";
import { ContextMixin } from "../utils/ContextMixin.sol";
import { EIP712Base } from "../utils/EIP712Base.sol";

// Error
/// @dev error throwned when the contract cap is exceeded
error CapExceed();

/**
 * Frak token on the ethereum mainnet, simpler
 */
/// @custom:security-contact contact@frak.id
contract FrakTokenL1 is ERC20Upgradeable, FrakAccessControlUpgradeable, EIP712Base, ContextMixin {
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
        __FrakAccessControlUpgradeable_init();

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
