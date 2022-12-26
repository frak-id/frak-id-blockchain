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
import { RewarderTestHelper } from "./RewarderTestHelper.sol";

/// Testing the frak l2 token
contract RewarderTest is RewarderTestHelper {
    
    function setUp() public {
        _baseSetUp();
    }

    /*
     * ===== TEST : initialize(
        address frkTokenAddr,
        address internalTokenAddr,
        address contentPoolAddr,
        address referralAddr,
        address foundationAddr
    ) =====
     */
    function testFailInitTwice() public {
        rewarder.initialize(address(0), address(0), address(0), address(0), address(0));
    }

    /*
     * ===== TEST : payUserDirectly(address listener, uint256 amount) =====
     */
    function testPayUserDirectly() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(1), 10);
    }

    function testFailPayUserContractPaused() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.pause();
        rewarder.payUserDirectly(address(1), 10);
    }

    function testFailPayUserInvalidRole() public withFrkToken(rewarderAddr) {
        rewarder.payUserDirectly(address(1), 10);
    }

    function testFailPayUserInvalidAddress() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(0), 10);
    }

    function testFailPayUserInvalidReward() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(1), 0);
    }

    function testFailPayUserTooLargeReward() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(1), 1_000_001 ether);
    }

    function testFailPayUserNotEnoughBalance() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(1), 11);
    }

    /*
     * ===== TEST : payCreatorDirectlyBatch(
        uint256[] calldata contentIds,
        uint256[] calldata amounts
    ) =====
     */
    function testPayCreatorDirectly() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.payUserDirectly(contentOwnerAddress, 10);
    }
}
