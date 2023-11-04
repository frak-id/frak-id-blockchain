// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { FrakToken } from "contracts/tokens/FrakToken.sol";
import { FraktionTokens } from "contracts/fraktions/FraktionTokens.sol";
import { MultiVestingWallets } from "contracts/wallets/MultiVestingWallets.sol";
import { VestingWalletFactory } from "contracts/wallets/VestingWalletFactory.sol";
import { FrakTreasuryWallet } from "contracts/wallets/FrakTreasuryWallet.sol";
import { ReferralPool } from "contracts/reward/referralPool/ReferralPool.sol";
import { Minter } from "contracts/minter/Minter.sol";
import { ContentPool } from "contracts/reward/contentPool/ContentPool.sol";
import { Rewarder } from "contracts/reward/Rewarder.sol";
import { FrakRoles } from "contracts/roles/FrakRoles.sol";
import { WalletMigrator } from "contracts/wallets/WalletMigrator.sol";

contract UpdateToEip712Diamond is UpgradeScript {
    function run() external {
        // Get the current treasury wallet address
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Update all the tokens contracts
        _updateToDiamondEip712(addresses);

        // Update the reward pools contracts
        _updateRewardPoolsContracts(addresses);

        // Deploy the migrator contract
        WalletMigrator walletMigrator = _deployMigrator(addresses);
        console.log("Migrator deployed to %s", address(walletMigrator));
    }

    /// @dev Update every contracts
    function _updateToDiamondEip712(UpgradeScript.ContractProxyAddresses memory addresses) internal deployerBroadcast {
        // Deploy every contract
        FrakToken frakToken = new FrakToken();
        FraktionTokens fraktionTokens = new FraktionTokens();

        // Update frk proxy
        bytes memory updateData = bytes.concat(FrakToken.updateToDiamondEip712.selector);
        _upgradeToAndCall(addresses.frakToken, address(frakToken), updateData);

        // Update fraktion proxy
        updateData = bytes.concat(FraktionTokens.updateToDiamondEip712.selector);
        _upgradeToAndCall(addresses.fraktionTokens, address(fraktionTokens), updateData);
    }

    function _updateRewardPoolsContracts(UpgradeScript.ContractProxyAddresses memory addresses)
        internal
        deployerBroadcast
    {
        ReferralPool referralPool = new ReferralPool();
        ContentPool contentPool = new ContentPool();
        Rewarder rewarder = new Rewarder();

        _upgradeTo(addresses.contentPool, address(contentPool));
        _upgradeTo(addresses.rewarder, address(rewarder));
        _upgradeTo(addresses.referralPool, address(referralPool));
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
