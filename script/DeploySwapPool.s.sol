// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoTokenPool} from "singleton-swapper/MonoTokenPool.sol";

contract DeploySwapPool is UpgradeScript {
    /// @dev The basis point for the pool to deploy (on 1e4)
    uint256 private constant BPS = 0.05e4;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Deploy the initial pool
        MonoTokenPool pool = _deployInitialPool(addresses.frakToken);

        // Log the pool address
        console.log("MonoTokenPool address: %s", address(pool));
    }

    /// @dev Fake some reward for a user
    function _deployInitialPool(address frkToken) internal deployerBroadcast returns (MonoTokenPool monotokenPool) {
        // Build the pool
        monotokenPool = new MonoTokenPool(frkToken, BPS);
    }
}
