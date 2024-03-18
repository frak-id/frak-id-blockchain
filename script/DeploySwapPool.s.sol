// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { MonoPool } from "swap-pool/MonoPool.sol";

contract DeploySwapPool is UpgradeScript {
    /// @dev The basis point for the pool to deploy
    uint256 private constant BPS = 100;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        console.log("Deploying to chain: %s", block.chainid);

        // Get the frak-labs address
        address feeReceiver = _currentCompanyWallets().frakLabs;

        // Deploy the initial pool
        MonoPool pool = _deployInitialPool(addresses.frakToken, feeReceiver);

        // Log the pool address
        console.log("MonoPool address: %s", address(pool));
    }

    /// @dev Fake some reward for a user
    function _deployInitialPool(
        address frkToken,
        address feeReceiver
    )
        internal
        deployerBroadcast
        returns (MonoPool monotokenPool)
    {
        // Build the pool, with 1% bps & 1% fee
        monotokenPool = new MonoPool(frkToken, address(0), 100, feeReceiver, 100);
    }
}
