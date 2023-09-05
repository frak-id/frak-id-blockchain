// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakToken } from "@frak/tokens/FrakToken.sol";
import { FraktionTokens } from "@frak/fraktions/FraktionTokens.sol";
import { MultiVestingWallets } from "@frak/wallets/MultiVestingWallets.sol";
import { VestingWalletFactory } from "@frak/wallets/VestingWalletFactory.sol";
import { FrakTreasuryWallet } from "@frak/wallets/FrakTreasuryWallet.sol";
import { ReferralPool } from "@frak/reward/referralPool/ReferralPool.sol";
import { Minter } from "@frak/minter/Minter.sol";
import { ContentPool } from "@frak/reward/contentPool/ContentPool.sol";
import { Rewarder } from "@frak/reward/Rewarder.sol";
import { FrakRoles } from "@frak/roles/FrakRoles.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/// Testing the frak l2 token
contract FrakTest is PRBTest {
    // User accounts
    address foundation;
    address deployer;
    address user;
    uint256 userPrivKey;

    // Contracts we will tests
    FrakToken frakToken;
    MultiVestingWallets multiVestingWallet;
    VestingWalletFactory vestingWalletFactory;
    FrakTreasuryWallet treasuryWallet;
    FraktionTokens fraktionTokens;
    Minter minter;
    ReferralPool referralPool;
    ContentPool contentPool;
    Rewarder rewarder;

    function _setupTests() internal {
        // Create users
        deployer = _newUser("deployer");
        foundation = _newUser("foundation");
        (user, userPrivKey) = _newUserWithPrivKey("user");

        // Deploy every contract
        _deployFrakContracts();
    }

    function _deployFrakContracts() internal {
        // Deploy each tokens related contract
        address _frkToken = _deployFrkToken();
        address _multiVestingWallet = _deployMultiVestingWallet(_frkToken);
        address _vestingWalletFactory = _deployVestingWalletFactory(_multiVestingWallet);
        address _treasuryWallet = _deployTreasuryWallet(_frkToken);

        // Grant the roles to the multi vesting wallet & treausry wallet
        _grantMultiVestingWalletRoles(_multiVestingWallet, _vestingWalletFactory);
        _grantTreasuryWalletWalletRoles(_treasuryWallet, _frkToken);

        // Deploy each contract related to the ecosystem
        address _fraktionTokens = _deployFraktionsToken();
        address _minter = _deployMinter(_frkToken, _fraktionTokens, foundation);
        address _referralPool = _deployReferralPool(_frkToken);
        address _contentPool = _deployContentPool(_frkToken);
        address _rewarder = _deployRewarder(_frkToken, _fraktionTokens, _contentPool, _referralPool, foundation);

        // Grant each roles
        _grantEcosystemRole(_rewarder, _contentPool, _referralPool, _fraktionTokens, _minter);

        // Save each contracts
        frakToken = FrakToken(_frkToken);
        multiVestingWallet = MultiVestingWallets(_multiVestingWallet);
        vestingWalletFactory = VestingWalletFactory(_vestingWalletFactory);
        treasuryWallet = FrakTreasuryWallet(_treasuryWallet);
        fraktionTokens = FraktionTokens(_fraktionTokens);
        minter = Minter(_minter);
        referralPool = ReferralPool(_referralPool);
        contentPool = ContentPool(_contentPool);
        rewarder = Rewarder(_rewarder);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Tokens related contracts & roles                      */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the frk token
    function _deployFrkToken() private asDeployer returns (address proxy) {
        // Deploy the initial frk token
        FrakToken implementation = new FrakToken();
        vm.label(address(implementation), "Impl-FrkToken");
        bytes memory initData = abi.encodeCall(FrakToken.initialize, ());
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FrkToken");
    }

    /// @dev Deploy the multi vesting wallet
    function _deployMultiVestingWallet(address _frkToken) private asDeployer returns (address proxy) {
        // Deploy the initial multi vesting wallets
        MultiVestingWallets implementation = new MultiVestingWallets();
        vm.label(address(implementation), "Impl-MultiVestingWallets");
        bytes memory initData = abi.encodeCall(MultiVestingWallets.initialize, (_frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "MultiVestingWallets");
    }

    /// @dev Deploy the vesting wallet factory
    function _deployVestingWalletFactory(address _multiVestingWallet) private asDeployer returns (address proxy) {
        // Deploy the initial vesting wallet factory contract
        VestingWalletFactory implementation = new VestingWalletFactory();
        vm.label(address(implementation), "Impl-VestingWalletFactory");
        bytes memory initData = abi.encodeCall(VestingWalletFactory.initialize, (_multiVestingWallet));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "VestingWalletFactory");
    }

    /// @dev Deploy the treasury wallet
    function _deployTreasuryWallet(address _frkToken) private asDeployer returns (address proxy) {
        // Deploy the initial vesting wallet factory contract
        FrakTreasuryWallet implementation = new FrakTreasuryWallet();
        vm.label(address(implementation), "Impl-FrakTreasuryWallet");
        bytes memory initData = abi.encodeCall(FrakTreasuryWallet.initialize, (_frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FrakTreasuryWallet");
    }

    /// @dev Grand the required roles to the multi vesting wallet
    function _grantMultiVestingWalletRoles(address _proxyAddress, address _vestingWalletFactory) private asDeployer {
        // Get the contract
        MultiVestingWallets implementation = MultiVestingWallets(_proxyAddress);
        implementation.grantRole(FrakRoles.VESTING_MANAGER, _vestingWalletFactory);
    }

    /// @dev Grand the required roles to the multi vesting wallet
    function _grantTreasuryWalletWalletRoles(address _proxyAddress, address _frkToken) private asDeployer {
        // Get the contract
        FrakTreasuryWallet implementation = FrakTreasuryWallet(_proxyAddress);
        implementation.grantRole(FrakRoles.MINTER, _frkToken);
    }

    /* -------------------------------------------------------------------------- */
    /*                     Ecosystem related contracts & roles                    */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the fraktion tokens
    function _deployFraktionsToken() private asDeployer returns (address proxy) {
        // Deploy the initial frk token
        FraktionTokens implementation = new FraktionTokens();
        vm.label(address(implementation), "Impl-FraktionTokens");
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("https://metadata.frak.id/json/{id.json}"));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "FraktionTokens");
    }

    /// @dev Deploy the minter
    function _deployMinter(
        address _frkToken,
        address _fraktionTokens,
        address _foundation
    )
        private
        asDeployer
        returns (address proxy)
    {
        // Deploy the initial frk token
        Minter implementation = new Minter();
        vm.label(address(implementation), "Impl-Minter");
        bytes memory initData = abi.encodeCall(Minter.initialize, (_frkToken, _fraktionTokens, _foundation));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "Minter");
    }

    /// @dev Deploy the referral pool
    function _deployReferralPool(address _frkToken) private asDeployer returns (address proxy) {
        // Deploy the initial frk token
        ReferralPool implementation = new ReferralPool();
        vm.label(address(implementation), "Impl-ReferralPool");
        bytes memory initData = abi.encodeCall(ReferralPool.initialize, (_frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "ReferralPool");
    }

    /// @dev Deploy the content pool
    function _deployContentPool(address _frkToken) private asDeployer returns (address proxy) {
        // Deploy the initial frk token
        ContentPool implementation = new ContentPool();
        vm.label(address(implementation), "Impl-ContentPool");
        bytes memory initData = abi.encodeCall(ContentPool.initialize, (_frkToken));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "ContentPool");
    }

    /// @dev Deploy the rewarder
    function _deployRewarder(
        address _frkToken,
        address _fraktionToken,
        address _contentPool,
        address _referralPool,
        address _foundation
    )
        private
        asDeployer
        returns (address proxy)
    {
        // Deploy the initial frk token
        Rewarder implementation = new Rewarder();
        vm.label(address(implementation), "Impl-Rewarder");
        bytes memory initData =
            abi.encodeCall(Rewarder.initialize, (_frkToken, _fraktionToken, _contentPool, _referralPool, _foundation));
        // Deploy the proxy
        proxy = _deployProxy(address(implementation), initData, "Rewarder");
    }

    /// @dev Grant the required roles to the rewarder
    function _grantEcosystemRole(
        address _rewarder,
        address _contentPool,
        address _referralPool,
        address _fraktionTokens,
        address _minter
    )
        private
        asDeployer
    {
        // Grant role for the rewarder
        ReferralPool(_referralPool).grantRole(FrakRoles.REWARDER, _rewarder);
        ContentPool(_contentPool).grantRole(FrakRoles.REWARDER, _rewarder);

        // Grant the callback roles on the content pool to the fraktion tokens
        ContentPool(_contentPool).grantRole(FrakRoles.TOKEN_CONTRACT, _fraktionTokens);

        // Grant the mint role to the minter
        FraktionTokens(_fraktionTokens).grantRole(FrakRoles.MINTER, _minter);
    }

    /* -------------------------------------------------------------------------- */
    /*                       Utils, to ease the test process                      */
    /* -------------------------------------------------------------------------- */

    modifier asDeployer() {
        vm.startPrank(deployer);
        _;
        vm.stopPrank();
    }

    function _newUser(string memory label) internal returns (address addr) {
        addr = address(bytes20(keccak256(abi.encode(label))));
        vm.label(addr, label);
    }

    function _newUserWithPrivKey(string memory label) internal returns (address addr, uint256 privKey) {
        privKey = uint256(keccak256(abi.encode(label)));
        addr = vm.addr(privKey);
        vm.label(addr, label);
    }

    /// @dev Deploy the given proxy
    function _deployProxy(
        address logic,
        bytes memory init,
        string memory label
    )
        internal
        returns (address createdAddress)
    {
        ERC1967Proxy proxyTemp = new ERC1967Proxy(logic, init);
        createdAddress = address(proxyTemp);
        vm.label(createdAddress, label);
    }
}
