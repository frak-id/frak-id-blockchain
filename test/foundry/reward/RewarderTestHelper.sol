// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "@frak/tokens/FraktionTokens.sol";
import "@frak/reward/pool/ContentPool.sol";
import "@frak/reward/pool/ReferralPool.sol";
import "@frak/reward/Rewarder.sol";
import "@frak/tokens/FraktionTokens.sol";
import "@frak/utils/FrakMath.sol";
import "@frak/wallets/MultiVestingWallets.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { FrkTokenTestHelper } from "../FrkTokenTestHelper.sol";

/// Testing the frak l2 token
contract RewarderTestHelper is FrkTokenTestHelper {
    using FrakMath for address;
    using FrakMath for uint256;

    FraktionTokens fraktionTokens;
    ContentPool contentPool;
    ReferralPool referralPool;
    address foundationAddr = address(13);

    address rewarderAddr;
    Rewarder rewarder;

    address contentOwnerAddress = address(2);

    function _baseSetUp() internal {
        _setupFrkToken();

        // Deploy fraktions token
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("test_url"));
        address fraktionProxyAddr = deployContract(address(new FraktionTokens()), initData);
        fraktionTokens = FraktionTokens(fraktionProxyAddr);

        // Deploy content pool
        initData = abi.encodeCall(ContentPool.initialize, (fraktionProxyAddr));
        address contentPoolProxyAddr = deployContract(address(new ContentPool()), initData);
        contentPool = ContentPool(contentPoolProxyAddr);

        // Deploy referral pool
        initData = abi.encodeCall(ReferralPool.initialize, (address(frakToken)));
        address referralProxyAddr = deployContract(address(new ReferralPool()), initData);
        referralPool = ReferralPool(referralProxyAddr);

        // Deploy fraktions token
        initData = abi.encodeCall(
            Rewarder.initialize,
            (address(frakToken), fraktionProxyAddr, contentPoolProxyAddr, referralProxyAddr, foundationAddr)
        );
        rewarderAddr = deployContract(address(new Rewarder()), initData);
        rewarder = Rewarder(rewarderAddr);

        // Grant the right roles
        _grantSetupRoles();
    }

    function _grantSetupRoles() private prankExecAsDeployer {
        fraktionTokens.grantRole(FrakRoles.MINTER, rewarderAddr);
        frakToken.grantRole(FrakRoles.MINTER, rewarderAddr);

        contentPool.grantRole(FrakRoles.REWARDER, rewarderAddr);
        referralPool.grantRole(FrakRoles.REWARDER, rewarderAddr);

        contentPool.grantRole(FrakRoles.TOKEN_CONTRACT, address(fraktionTokens));

        fraktionTokens.registerNewCallback(address(contentPool));
    }

    /*
     * ===== UTILS=====
     */

    function mintAContent() public returns (uint256) {
        prankDeployer();
        return fraktionTokens.mintNewContent(contentOwnerAddress);
    }
}
