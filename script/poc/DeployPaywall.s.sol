// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "../utils/UpgradeScript.s.sol";
import { Paywall } from "contracts/paywall/Paywall.sol";
import { FrakTreasuryWallet } from "contracts/wallets/FrakTreasuryWallet.sol";
import { FrakRoles } from "contracts/roles/FrakRoles.sol";

contract DeployPaywall is UpgradeScript {
    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();
        UpgradeScript.CompanyWalletAddresses memory companyWallets = _currentCompanyWallets();

        console.log("Deploying to chain: %s", block.chainid);

        // Only allow mumbai deployment for now
        if (block.chainid != 80_002) {
            console.log("Unsupported chain id: %s", block.chainid);
            return;
        }

        // Grant the airdrop role
        _grantAirdropRole(addresses.frakTreasuryWallet, 0x35F3e191523C8701aD315551dCbDcC5708efD7ec);

        // Deploy the initial paywall
        Paywall paywall = _deployPaywall(addresses.frakToken, addresses.fraktionTokens, companyWallets.frakLabs);

        // Log the paywall address
        console.log("Paywall address: %s", address(paywall));
    }

    /// @dev Grant the frk airdroper the right roles
    function _grantAirdropRole(address treasuryWallet, address airdropper) internal deployerBroadcast {
        FrakTreasuryWallet(treasuryWallet).grantRole(FrakRoles.MINTER, airdropper);
    }

    /// @dev Fake some reward for a user
    function _deployPaywall(
        address frkToken,
        address fraktionToken,
        address frakLabsWallet
    )
        internal
        deployerBroadcast
        returns (Paywall)
    {
        // Deploy the initial frk token
        Paywall implementation = new Paywall();
        vm.label(address(implementation), "Paywall-Impl");
        bytes memory initData = abi.encodeCall(Paywall.initialize, (frkToken, fraktionToken, frakLabsWallet));
        // Deploy the proxy
        address proxy = _deployProxy(address(implementation), initData, "Paywall");
        return Paywall(proxy);
    }
}
