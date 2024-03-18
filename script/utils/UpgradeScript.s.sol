// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import { UUPSUpgradeable } from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @author @KONFeature
 * @title UpgradeScript
 * @dev This contract provides us the base tools to deploy contract updates
 *
 * @custom:security-contact contact@frak.id
 */
abstract contract UpgradeScript is Script {
    /// @dev Struct containing each one of our proxy addresses
    struct ContractProxyAddresses {
        address frakToken;
        address fraktionTokens;
        address multiVestingWallet;
        address vestingWalletFactory;
        address referralPool;
        address contentPool;
        address rewarder;
        address minter;
        address frakTreasuryWallet;
        address swapPool;
        address walletMigrator;
        address paywall;
    }

    struct CompanyWalletAddresses {
        address frakLabs;
        address frakFoundation;
    }

    /// @dev Mapping of chainId -> proxy addresses
    mapping(uint256 chain => ContractProxyAddresses contractAddresses) public contractAddresses;
    mapping(uint256 chain => CompanyWalletAddresses companyWallets) public companyWallets;

    /* -------------------------------------------------------------------------- */
    /*                 Constructor saving current proxy addresses                 */
    /* -------------------------------------------------------------------------- */

    constructor() {
        // Polygon proxy address
        contractAddresses[137] = ContractProxyAddresses({
            frakToken: 0x6261E4a478C98419EaFa6289509C49058D21Df8c,
            fraktionTokens: 0x4B1611803687Ab821E1b670fE94CB93303D94F8a,
            multiVestingWallet: 0xCD550f3eFF6d2bA94d8A106bE3c0fE46D5D38bDe,
            vestingWalletFactory: 0xb8D79C7Bca3994dd5B4A80AD1c088CEBCd01f7F6,
            referralPool: 0x166d8CFEe1919bC2e8c7AdBB34F1613194e9C599,
            contentPool: 0xDCB34659B83C4F8708fd7AcAA3755547BF8BBcA0,
            rewarder: 0x8D9fa601DA1416b087E9db6B6EaD63D4920A4528,
            minter: 0x1adc8CAaA35551730eCd82e0eEA683Aa90dB6cf0,
            frakTreasuryWallet: 0x7053f61CEA3B7C3b5f0e14de6eEdB01cA1850408,
            swapPool: 0xC01677Ec5eF3607364125Ab84F6FBb7d95B3D545,
            walletMigrator: 0xC9f4a01219240aEDfe9502fff0bdEEa5ea83E795,
            paywall: address(0)
        });
        // Mumbai proxy address
        contractAddresses[80_001] = ContractProxyAddresses({
            frakToken: 0xbCeE0E1C02E91EAFaEd69eD2B1DC5199789575df,
            fraktionTokens: 0x00ec5dd47eD5341A43d66F8aA7b6793277d1e29E,
            multiVestingWallet: 0x08F674c3577f759D315336ae5a7ff6ea5bE2c35E,
            vestingWalletFactory: 0x20a174B8b62CF69a0b1700140818b6345FBC8B34,
            referralPool: 0x40AF2De1319F32e9eEEeB8F203FeB0dfA446F897,
            contentPool: 0xf10eF8435FD583B7007C5984DB27462B4401F380,
            rewarder: 0x0bD2a225E2c6173b42b907Cc4424076327D90F6F,
            minter: 0x8964e2Ed5fF27358c62a761f23957bd2b5165779,
            frakTreasuryWallet: 0x7CC62E1ecd246153DF4997352ec9C5fF172EE08C,
            swapPool: 0xa5C6ff96B2417d5477d0ab27881b3D60675E0d30,
            walletMigrator: 0xC2F4685B8d9fafc3172abA9a7FFd4B0Dd2bd2D5e,
            paywall: 0xD2a304D5E3427AeF3319De435b530d4B3f7eab5F
        });
        // Amoy proxy address
        contractAddresses[80_002] = ContractProxyAddresses({
            frakToken: 0x183a08d221163335fC20B07E53236403CE9dc03d,
            fraktionTokens: 0xa6713941ABA860DA9fd6CCA53E5b5583E82Af475,
            multiVestingWallet: 0x4Be1153c6dc18BbE75b8F8E1C9CA52cbbEE38215,
            vestingWalletFactory: 0x96a0B8dA8D2c38352e2A910f6E8124dAA4a44a8d,
            referralPool: 0x975dfE2EAa974933e772D25A61640DB1088AAD9e,
            contentPool: 0x0DF67c0F092cC595104B4586Ffd2F30790E31f8f,
            rewarder: 0x23BAC39b7849E029F77d981485B6259172E3558e,
            minter: 0x726BA97e5e4a8Fb630cdBf12383Bd9905CEDA074,
            frakTreasuryWallet: 0xC1B4bFFEC8ea8E0BE9D923358652A32911c4d2Ce,
            swapPool: 0x78006cCa3dC37ED26139c916B97Ef997323D58e0,
            walletMigrator: 0xef7336D5be2F9da8a149e61a926b0f2B85373e6e,
            paywall: 0x438fb6eEDBa3C300F5a1f636F33cAf20715b46f5
        });

        // Polygon company wallets
        companyWallets[137] = CompanyWalletAddresses({
            frakLabs: 0x9d92de42aB5BbB59d6c39fdabB55B998c83Da97c,
            frakFoundation: 0x11D2fF1540F2c275EE199500320Af58a97E9Da33
        });
        // Mumbai company wallets
        companyWallets[80_001] = CompanyWalletAddresses({
            frakLabs: 0x1f20a905A41EDD54b6803999Ac62D003953a810a,
            frakFoundation: 0x1f20a905A41EDD54b6803999Ac62D003953a810a
        });
        // Amoy company wallets
        companyWallets[80_002] = CompanyWalletAddresses({
            frakLabs: 0x1f20a905A41EDD54b6803999Ac62D003953a810a,
            frakFoundation: 0x1f20a905A41EDD54b6803999Ac62D003953a810a
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                           Internal write functions                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Set new deployed proxy addresses
     * @param proxyAddresses The new proxy addresses
     */
    function _setProxyAddresses(ContractProxyAddresses memory proxyAddresses) internal {
        // Then return the address
        contractAddresses[block.chainid] = proxyAddresses;
    }

    /**
     * @dev Write new deployed proxy addresses
     * @param proxy The proxy addresses
     * @param implementation The new implementation addresses
     */
    function _upgradeTo(address proxy, address implementation) internal {
        UUPSUpgradeable(proxy).upgradeTo(implementation);
    }

    /**
     * @dev Write new deployed proxy addresses
     * @param proxy The proxy addresses
     * @param implementation The new implementation addresses
     * @param data The data to call during the upgrade
     */
    function _upgradeToAndCall(address proxy, address implementation, bytes memory data) internal {
        UUPSUpgradeable(proxy).upgradeToAndCall(implementation, data);
    }

    /**
     * @dev Deploy a new proxy with the given implementation
     * @param implementation The implementation addresses
     * @param data The data to call during the upgrade
     * @param name The name of the contract to deploy
     * @return proxyAddress The address of the deployed proxy
     */
    function _deployProxy(
        address implementation,
        bytes memory data,
        string memory name
    )
        internal
        returns (address proxyAddress)
    {
        string memory label = string.concat("Proxy-", name);
        console.log("Deploying proxy %s for implementation at %s", label, implementation);

        ERC1967Proxy deployedProxy = new ERC1967Proxy(implementation, data);
        proxyAddress = address(deployedProxy);
        vm.label(proxyAddress, label);
        console.log("Proxy for %s deployed at %s", name, proxyAddress);
    }

    /// @dev Get the deployer private key
    function _deployerPrivateKey() internal view returns (uint256) {
        return vm.envUint("DEPLOY_PRIV_KEY");
    }

    /// @dev Get the current deployer address
    function _deployerAddress() internal view returns (address) {
        return vm.addr(_deployerPrivateKey());
    }

    /* -------------------------------------------------------------------------- */
    /*                           Internal read functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Read the current proxy addresses
    /// @return addresses The current proxy addresses
    function _currentProxyAddresses() internal view returns (ContractProxyAddresses memory addresses) {
        addresses = contractAddresses[block.chainid];
        // If one of the addresses is 0, revert
        require(addresses.frakToken != address(0), "UpgradeScript: frakToken address is 0");
        require(addresses.fraktionTokens != address(0), "UpgradeScript: fraktionTokens address is 0");
        require(addresses.multiVestingWallet != address(0), "UpgradeScript: multiVestingWallet address is 0");
        require(addresses.vestingWalletFactory != address(0), "UpgradeScript: vestingWalletFactory address is 0");
        require(addresses.referralPool != address(0), "UpgradeScript: referralPool address is 0");
        require(addresses.contentPool != address(0), "UpgradeScript: contentPool address is 0");
        require(addresses.rewarder != address(0), "UpgradeScript: rewarder address is 0");
        require(addresses.minter != address(0), "UpgradeScript: minter address is 0");
        require(addresses.frakTreasuryWallet != address(0), "UpgradeScript: frakTreasuryWallet address is 0");
    }

    /// @dev Read the current company wallets
    /// @return addresses The current company wallets
    function _currentCompanyWallets() internal view returns (CompanyWalletAddresses memory addresses) {
        addresses = companyWallets[block.chainid];
        // If one of the addresses is 0, revert
        require(addresses.frakLabs != address(0), "UpgradeScript: frakLabs address is 0");
        require(addresses.frakFoundation != address(0), "UpgradeScript: frakFoundation address is 0");
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */

    modifier deployerBroadcast() {
        uint256 deployerPrivateKey = _deployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}
