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
        UpgradeScript.CompanyWalletAddresses memory companyWallets = _currentCompanyWallets();

        _updateRewarderAndMinter(addresses, companyWallets);
    }

    /// @dev Update every contracts
    function _updateRewarderAndMinter(
        UpgradeScript.ContractProxyAddresses memory addresses,
        UpgradeScript.CompanyWalletAddresses memory companyWallets
    )
        internal
        deployerBroadcast
    {
        Minter minter = Minter(addresses.minter);
        minter.addContentForCreator(companyWallets.frakFoundation);
    }
}
