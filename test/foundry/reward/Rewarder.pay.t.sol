// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { FrakMath } from "@frak/utils/FrakMath.sol";
import "forge-std/Vm.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { RewarderTestHelper } from "./RewarderTestHelper.sol";

/// Testing the frak l2 token
contract RewarderPayTest is RewarderTestHelper {
    using FrakMath for uint256;

    uint256 contentId;

    function setUp() public {
        _baseSetUp();

        contentId = mintAContent();
    }

    /*
     * ===== TEST : payUser(
        address listener,
        uint8 contentType,
        uint256[] calldata contentIds,
        uint16[] calldata listenCounts
    )s =====
     */
    function testPayUser() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint16[] memory listenCounts = new uint16[](1);
        listenCounts[0] = 10;
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
    }

    function testPayUserFuzz(uint16[] memory listenCounts) public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.assume(listenCounts.length < 21);

        uint256[] memory contentIds = new uint256[](listenCounts.length);
        for (uint256 i; i < contentIds.length; ) {
            unchecked {
                contentIds[i] = contentId;
                listenCounts[i] = 10;
                i++;
            }
        }

        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }
}
