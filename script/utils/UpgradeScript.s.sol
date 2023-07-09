// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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
    }

    /// @dev Mapping of chainId -> proxy addresses
    mapping(uint256 chain => ContractProxyAddresses contractAddresses) public contractAddresses;

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
            swapPool: 0x01 // TODO: Not deployed yet
        });
        // Mumbai proxy address
        contractAddresses[80001] = ContractProxyAddresses({
            frakToken: 0xbCeE0E1C02E91EAFaEd69eD2B1DC5199789575df,
            fraktionTokens: 0x00ec5dd47eD5341A43d66F8aA7b6793277d1e29E,
            multiVestingWallet: 0x08F674c3577f759D315336ae5a7ff6ea5bE2c35E,
            vestingWalletFactory: 0x20a174B8b62CF69a0b1700140818b6345FBC8B34,
            referralPool: 0x40AF2De1319F32e9eEEeB8F203FeB0dfA446F897,
            contentPool: 0xf10eF8435FD583B7007C5984DB27462B4401F380,
            rewarder: 0x0bD2a225E2c6173b42b907Cc4424076327D90F6F,
            minter: 0x8964e2Ed5fF27358c62a761f23957bd2b5165779,
            frakTreasuryWallet: 0x7CC62E1ecd246153DF4997352ec9C5fF172EE08C,
            swapPool: 0xe4AF7F707E9BC6082f35c8cDc7567015CA2dBbec
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                           Internal write method's                          */
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
    function _deployProxy(address implementation, bytes memory data, string memory name)
        internal
        returns (address proxyAddress)
    {
        string memory label = string.concat("Proxy-", name);
        console.log("Deploying proxy %s for implementation at %s", label, implementation);

        ERC1967Proxy deployedProxy = new ERC1967Proxy(implementation, data);
        proxyAddress = address(deployedProxy);
        vm.label(proxyAddress, label);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Internal read method's                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Read the current proxy addresses
     * @return addresses The current proxy addresses
     */
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

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */

    modifier deployerBroadcast() {
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_PRIV_KEY");
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}
