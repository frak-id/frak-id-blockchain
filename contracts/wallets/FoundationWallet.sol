// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Represent our foundation wallet contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract FoundationWallet is PaymentSplitterUpgradeable, SybelAccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address sybelCorp) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Add the initial sybel corp payee
        address[] memory initialPayee = SybelMath.asSingletonArray(sybelCorp);
        uint256[] memory initialSharee = SybelMath.asSingletonArray(100);
        __PaymentSplitter_init(initialPayee, initialSharee);
    }
}
