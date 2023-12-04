// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

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

        // Get the frk labs & foundation address
        address labsWallet;
        address foundationWallet;
        if(block.chainid == 137) {
            labsWallet = 0x9d92de42aB5BbB59d6c39fdabB55B998c83Da97c;
            foundationWallet = 0x11D2fF1540F2c275EE199500320Af58a97E9Da33;
        } else {
            labsWallet = 0x1f20a905A41EDD54b6803999Ac62D003953a810a;
            foundationWallet = 0x1f20a905A41EDD54b6803999Ac62D003953a810a;
        }

        // Build our rewarder update data
        bytes memory rewarderUpdateData = abi.encodeCall(Rewarder.updateFeeReceiver, (labsWallet));

        // Build our minter update data
        bytes memory minterUpdateData = abi.encodeCall(Minter.updateFeeReceiver, (foundationWallet));

        // Update all the proxy
        _updateRewarderAndMinter(addresses, rewarderUpdateData, minterUpdateData);
    }

    /// @dev Update every contracts
    function _updateRewarderAndMinter(UpgradeScript.ContractProxyAddresses memory addresses, bytes memory rewarderUpdateData, bytes memory minterUpdateData) internal deployerBroadcast {
        // Deploy the new rewarder & minter
        Rewarder rewarder = new Rewarder();
        Minter minter = new Minter();

        // Update every proxy
        _upgradeToAndCall(addresses.rewarder, address(rewarder), rewarderUpdateData);
        _upgradeToAndCall(addresses.minter, address(minter), minterUpdateData);
    }
}
