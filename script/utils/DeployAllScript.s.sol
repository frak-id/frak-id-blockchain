// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import { UpgradeScript } from "./UpgradeScript.s.sol";
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

contract DeployAllScript is UpgradeScript {
    constructor() { }

    function _setUpTestEnv() internal {
        // Deploy each tokens related contract
        address frkToken = _deployFrkToken();
        address multiVestingWallet = _deployMultiVestingWallet(frkToken);
        address vestingWalletFactory = _deployVestingWalletFactory(multiVestingWallet);
        address treasuryWallet = _deployTreasuryWallet(frkToken);

        // Grant the roles to the multi vesting wallet & treausry wallet
        _grantMultiVestingWalletRoles(multiVestingWallet, vestingWalletFactory);
        _grantTreasuryWalletWalletRoles(treasuryWallet, frkToken);

        // Deploy each contract related to the ecosystem
        address foundation = address(this);
        address fraktionTokens = _deployFraktionsToken();
        address minter = _deployMinter(frkToken, fraktionTokens, foundation);
        address referralPool = _deployReferralPool(frkToken);
        address contentPool = _deployContentPool(frkToken);
        address rewarder = _deployRewarder(frkToken, fraktionTokens, contentPool, referralPool, foundation);

        // Grant each roles
        _grantEcosystemRole(rewarder, contentPool, referralPool, fraktionTokens, minter);

        // Once all set, save each address
        UpgradeScript.ContractProxyAddresses memory addresses = UpgradeScript.ContractProxyAddresses({
            frakToken: frkToken,
            fraktionTokens: fraktionTokens,
            multiVestingWallet: multiVestingWallet,
            vestingWalletFactory: vestingWalletFactory,
            referralPool: referralPool,
            contentPool: contentPool,
            rewarder: rewarder,
            minter: minter,
            frakTreasuryWallet: treasuryWallet,
            swapPool: address(1),
            walletMigrator: address(1)
        });
        _setProxyAddresses(addresses);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Tokens related contracts & roles                      */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the frk token
    function _deployFrkToken() private deployerBroadcast returns (address proxy) {
        // Deploy the initial frk token
        FrakToken implementation = new FrakToken();
        vm.label(address(implementation), "FrkToken");
        bytes memory initData = abi.encodeCall(FrakToken.initialize, ());
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FrkToken");
    }

    /// @dev Deploy the multi vesting wallet
    function _deployMultiVestingWallet(address frkToken) private deployerBroadcast returns (address proxy) {
        // Deploy the initial multi vesting wallets
        MultiVestingWallets implementation = new MultiVestingWallets();
        vm.label(address(implementation), "MultiVestingWallets");
        bytes memory initData = abi.encodeCall(MultiVestingWallets.initialize, (frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "MultiVestingWallets");
    }

    /// @dev Deploy the vesting wallet factory
    function _deployVestingWalletFactory(address multiVestingWallet)
        private
        deployerBroadcast
        returns (address proxy)
    {
        // Deploy the initial vesting wallet factory contract
        VestingWalletFactory implementation = new VestingWalletFactory();
        vm.label(address(implementation), "VestingWalletFactory");
        bytes memory initData = abi.encodeCall(VestingWalletFactory.initialize, (multiVestingWallet));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "VestingWalletFactory");
    }

    /// @dev Deploy the treasury wallet
    function _deployTreasuryWallet(address frkToken) private deployerBroadcast returns (address proxy) {
        // Deploy the initial vesting wallet factory contract
        FrakTreasuryWallet implementation = new FrakTreasuryWallet();
        vm.label(address(implementation), "FrakTreasuryWallet");
        bytes memory initData = abi.encodeCall(FrakTreasuryWallet.initialize, (frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FrakTreasuryWallet");
    }

    /// @dev Grand the required roles to the multi vesting wallet
    function _grantMultiVestingWalletRoles(
        address proxyAddress,
        address vestingWalletFactory
    )
        private
        deployerBroadcast
    {
        // Get the contract
        MultiVestingWallets implementation = MultiVestingWallets(proxyAddress);
        implementation.grantRole(FrakRoles.VESTING_MANAGER, vestingWalletFactory);
    }

    /// @dev Grand the required roles to the multi vesting wallet
    function _grantTreasuryWalletWalletRoles(address proxyAddress, address frkToken) private deployerBroadcast {
        FrakToken(frkToken).grantRole(FrakRoles.MINTER, proxyAddress);
    }

    /* -------------------------------------------------------------------------- */
    /*                     Ecosystem related contracts & roles                    */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the fraktion tokens
    function _deployFraktionsToken() private deployerBroadcast returns (address proxy) {
        // Deploy the initial frk token
        FraktionTokens implementation = new FraktionTokens();
        vm.label(address(implementation), "FraktionTokens");
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("https://metadata.frak.id/json/{id.json}"));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FraktionTokens");
    }

    /// @dev Deploy the minter
    function _deployMinter(
        address frkToken,
        address fraktionTokens,
        address foundation
    )
        private
        deployerBroadcast
        returns (address proxy)
    {
        // Deploy the initial frk token
        Minter implementation = new Minter();
        vm.label(address(implementation), "Minter");
        bytes memory initData = abi.encodeCall(Minter.initialize, (frkToken, fraktionTokens, foundation));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "Minter");
    }

    /// @dev Deploy the referral pool
    function _deployReferralPool(address frkToken) private deployerBroadcast returns (address proxy) {
        // Deploy the initial frk token
        ReferralPool implementation = new ReferralPool();
        vm.label(address(implementation), "ReferralPool");
        bytes memory initData = abi.encodeCall(ReferralPool.initialize, (frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "ReferralPool");
    }

    /// @dev Deploy the content pool
    function _deployContentPool(address frkToken) private deployerBroadcast returns (address proxy) {
        // Deploy the initial frk token
        ContentPool implementation = new ContentPool();
        vm.label(address(implementation), "ContentPool");
        bytes memory initData = abi.encodeCall(ContentPool.initialize, (frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "ContentPool");
    }

    /// @dev Deploy the rewarder
    function _deployRewarder(
        address frkToken,
        address fraktionToken,
        address contentPool,
        address referralPool,
        address foundation
    )
        private
        deployerBroadcast
        returns (address proxy)
    {
        // Deploy the initial frk token
        Rewarder implementation = new Rewarder();
        vm.label(address(implementation), "Rewarder");
        bytes memory initData =
            abi.encodeCall(Rewarder.initialize, (frkToken, fraktionToken, contentPool, referralPool, foundation));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "Rewarder");
    }

    /// @dev Grant the required roles to the rewarder
    function _grantEcosystemRole(
        address rewarder,
        address contentPool,
        address referralPool,
        address fraktionTokens,
        address minter
    )
        private
        deployerBroadcast
    {
        // Grant role for the rewarder
        ReferralPool(referralPool).grantRole(FrakRoles.REWARDER, rewarder);
        ContentPool(contentPool).grantRole(FrakRoles.REWARDER, rewarder);

        // Grant the callback roles on the content pool to the fraktion tokens
        ContentPool(contentPool).grantRole(FrakRoles.TOKEN_CONTRACT, fraktionTokens);

        // Grant the mint role to the minter
        FraktionTokens(fraktionTokens).grantRole(FrakRoles.MINTER, minter);
    }
}
