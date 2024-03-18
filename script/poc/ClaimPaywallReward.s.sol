// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { UpgradeScript } from "../utils/UpgradeScript.s.sol";
import { ContentId } from "contracts/libs/ContentId.sol";
import { Paywall } from "contracts/paywall/Paywall.sol";
import { IPaywall } from "contracts/paywall/IPaywall.sol";
import { FrakTreasuryWallet } from "contracts/wallets/FrakTreasuryWallet.sol";
import { FrakRoles } from "contracts/roles/FrakRoles.sol";

contract SetupTestPaywall is UpgradeScript {
    function run() external {
        // Get the current treasury wallet address
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;
        Paywall paywall = Paywall(addresses.paywall);

        uint256 availableFounds = paywall.getAvailableFounds(owner);
        console.log("Available founds: %s", availableFounds);

        address airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
        _allowTmpAirdropper(FrakTreasuryWallet(addresses.frakTreasuryWallet), airdropper);
    }

    function _allowTmpAirdropper(FrakTreasuryWallet _treasuryWallet, address airdropper) internal deployerBroadcast {
        _treasuryWallet.grantRole(FrakRoles.MINTER, airdropper);
    }
}
