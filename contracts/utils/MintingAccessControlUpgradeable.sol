// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

/// @custom:security-contact crypto-support@sybel.co
abstract contract MintingAccessControlUpgradeable is SybelAccessControlUpgradeable {
    function __MintingAccessControlUpgradeable_init() internal onlyInitializing {
        __SybelAccessControlUpgradeable_init();

        _grantRole(SybelRoles.MINTER, _msgSender());
    }
}
