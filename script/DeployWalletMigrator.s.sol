// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { MonoPool } from "swap-pool/MonoPool.sol";
import { WalletMigrator } from "contracts/wallets/WalletMigrator.sol";

contract DeployWalletMigrator is UpgradeScript {
    /// @dev The basis point for the pool to deploy
    uint256 private constant BPS = 100;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Deploy the migrator contract
        WalletMigrator walletMigrator = _deployMigrator(addresses);
        console.log("Migrator deployed to %s", address(walletMigrator));
    }

    /// @dev Deploy the migrator contract
    function _deployMigrator(UpgradeScript.ContractProxyAddresses memory addresses)
        internal
        deployerBroadcast
        returns (WalletMigrator)
    {
        // Build the wallet migrator we will test
        return new WalletMigrator(
            addresses.frakToken, 
            addresses.fraktionTokens, 
            addresses.rewarder, 
            addresses.contentPool, 
            addresses.referralPool
        );
    }
}
