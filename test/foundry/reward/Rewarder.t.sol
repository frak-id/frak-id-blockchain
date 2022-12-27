// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { InvalidReward } from "@frak/reward/Rewarder.sol";
import { RewarderTestHelper } from "./RewarderTestHelper.sol";
import { NotAuthorized, InvalidAddress, ContractPaused, BadgeTooLarge } from "@frak/utils/FrakErrors.sol";

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
    function test_fail_InitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize(address(0), address(0), address(0), address(0), address(0));
    }

    /*
     * ===== TEST : updateTpu(uint256 newTpu) =====
     */
    function test_updateTpu() public prankExecAsDeployer {
        rewarder.updateTpu(1 ether);
        assertEq(rewarder.tokenGenerationFactor(), 1 ether);
    }

    function test_fail_updateTpu_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateTpu(1 ether);
    }

    /*
     * ===== TEST : updateContentBadge(
        uint256 contentId,
        uint256 badge
    ) =====
     */
    function test_updateContentBadge() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.updateContentBadge(contentId, 2 ether);
        assertEq(rewarder.getContentBadge(contentId), 2 ether);
    }

    function test_fail_updateContentBadge_ContractPaused() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.pause();

        vm.expectRevert(ContractPaused.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_fail_updateContentBadge_NotAuthorized() public {
        prankDeployer();
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);

        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_fail_updateContentBadge_BadgeCapReached() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);

        vm.expectRevert(BadgeTooLarge.selector);
        rewarder.updateContentBadge(contentId, 1001 ether);
    }

    /*
     * ===== TEST : updateListenerBadge(
        address listener,
        uint256 badge
    ) =====
     */
    function test_updateListenerBadge() public prankExecAsDeployer {
        rewarder.updateListenerBadge(address(1), 2 ether);
        assertEq(rewarder.getListenerBadge(address(1)), 2 ether);
    }

    function test_fail_updateListenerBadge_ContractPaused() public prankExecAsDeployer {
        rewarder.pause();
        vm.expectRevert(ContractPaused.selector);
        rewarder.updateListenerBadge(address(1), 2 ether);
    }

    function test_fail_updateListenerBadge_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateListenerBadge(address(1), 2 ether);
    }

    function test_fail_updateListenerBadge_BadgeCapReached() public prankExecAsDeployer {
        vm.expectRevert(BadgeTooLarge.selector);
        rewarder.updateListenerBadge(address(1), 1001 ether);
    }
}
