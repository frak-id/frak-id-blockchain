// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";
import "../utils/FrakMath.sol";
import "../utils/FrakRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/FrakAccessControlUpgradeable.sol";

/**
 * @dev Represent our foundation wallet contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract FoundationWallet is PaymentSplitterUpgradeable, FrakAccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address sybelCorp) external initializer {
        __FrakAccessControlUpgradeable_init();

        // Add the initial sybel corp payee
        address[] memory initialPayee = FrakMath.asSingletonArray(sybelCorp);
        uint256[] memory initialSharee = FrakMath.asSingletonArray(100);
        __PaymentSplitter_init(initialPayee, initialSharee);
    }
}
