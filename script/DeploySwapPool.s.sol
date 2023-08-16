// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoPool} from "swap-pool/MonoPool.sol";

contract DeploySwapPool is UpgradeScript {
    /// @dev The basis point for the pool to deploy
    uint256 private constant BPS = 100;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Get the wmatic address
        address wmatic;
        if (block.chainid == 80001) {
            wmatic = address(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
        } else if (block.chainid == 137) {
            wmatic = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        } else {
            console.log("Unsupported chain id: %s", block.chainid);
            return;
        }

        // Address of the fee receiver owner
        address poolOwner = address(0x7caF754C934710D7C73bc453654552BEcA38223F);

        // Deploy the initial pool
        MonoPool pool = _deployInitialPool(addresses.frakToken, wmatic, poolOwner);

        // Log the pool address
        console.log("MonoPool address: %s", address(pool));
    }

    /// @dev Fake some reward for a user
    function _deployInitialPool(address frkToken, address wMatic, address feeReceiver)
        internal
        deployerBroadcast
        returns (MonoPool monotokenPool)
    {
        // Build the pool, with 1% bps & 1% fee
        monotokenPool = new MonoPool(frkToken, wMatic, 100, feeReceiver, 100);
    }
}
