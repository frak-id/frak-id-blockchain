// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {FrakAccessControlUpgradeable} from "./FrakAccessControlUpgradeable.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";

/// @custom:security-contact contact@frak.id
abstract contract MintingAccessControlUpgradeable is FrakAccessControlUpgradeable {
    function __MintingAccessControlUpgradeable_init() internal onlyInitializing {
        __FrakAccessControlUpgradeable_init();

        _grantRole(FrakRoles.MINTER, _msgSender());
    }
}
