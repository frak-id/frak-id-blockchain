// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

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

contract UpdateAllScript is UpgradeScript {
    function run() external {
        // Get the current treasury wallet address
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Update all the proxy
        _updateAll(addresses);
    }

    /// @dev Update every contracts
    function _updateAll(UpgradeScript.ContractProxyAddresses memory addresses) internal deployerBroadcast {
        // Deploy every contract
        FrakToken frakToken = new FrakToken();
        MultiVestingWallets multiVestingWallets = new MultiVestingWallets();
        VestingWalletFactory vestingWalletFactory = new VestingWalletFactory();
        FrakTreasuryWallet frakTreasuryWallet = new FrakTreasuryWallet();
        FraktionTokens fraktionTokens = new FraktionTokens();
        ReferralPool referralPool = new ReferralPool();
        Minter minter = new Minter();
        ContentPool contentPool = new ContentPool();
        Rewarder rewarder = new Rewarder();

        // Update every proxy
        _upgradeTo(addresses.frakToken, address(frakToken));
        _upgradeTo(addresses.multiVestingWallet, address(multiVestingWallets));
        _upgradeTo(addresses.vestingWalletFactory, address(vestingWalletFactory));
        _upgradeTo(addresses.frakTreasuryWallet, address(frakTreasuryWallet));
        _upgradeTo(addresses.fraktionTokens, address(fraktionTokens));
        _upgradeTo(addresses.referralPool, address(referralPool));
        _upgradeTo(addresses.minter, address(minter));
        _upgradeTo(addresses.contentPool, address(contentPool));
        _upgradeTo(addresses.rewarder, address(rewarder));
    }
}
