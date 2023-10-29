// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { Rewarder } from "contracts/reward/Rewarder.sol";
import { IRewarder } from "contracts/reward/IRewarder.sol";
import { ContentId } from "contracts/libs/ContentId.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";
import { RewardListenParamLib, RewardListenParam } from "contracts/reward/RewardListenParam.sol";

/// @dev Testing methods on the Rewarder
contract RewarderTest is FrakTest {
    function setUp() public {
        _setupTests();

        // Add some frk to the rewarder
        vm.prank(deployer);
        frakToken.mint(address(rewarder), 1_500_000 ether);
    }

    function test_pay_FreeFraktion_ok() public {
        RewardListenParam[] memory listenParams = _payParameters();
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);

        // Assert that the user got some rewards
        uint256 availableBalance = rewarder.getAvailableFounds(user);
        assertGt(availableBalance, 0);
        assertEq(availableBalance, 0.007 ether);
        // Assert that the owner got some rewards
        assertGt(rewarder.getAvailableFounds(contentOwner), 0);
        // Assert that the content pool received no reward
        assertEq(frakToken.balanceOf(address(contentPool)), 0);

        // Claim the founds
        vm.prank(user);
        rewarder.withdrawFounds();

        // Ensure the founds is withdraw with 2% fees
        assertEq(frakToken.balanceOf(user), availableBalance * 98 / 100);
        assertEq(rewarder.getAvailableFounds(user), 0);
    }

    function test_pay_PayedFraktions_ok() public userWithFraktion {
        uint256 initialFrkMinted = rewarder.getFrkMinted();

        RewardListenParam[] memory listenParams = _payParameters();
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);

        // Assert that the user got some rewards
        uint256 availableBalance = rewarder.getAvailableFounds(user);
        assertGt(availableBalance, 0);
        assertEq(availableBalance, 2.527 ether);
        // Ensure the frk minted amount has decreased
        assertGt(rewarder.getFrkMinted(), initialFrkMinted);
        // Assert that the owner got some rewards
        assertGt(rewarder.getAvailableFounds(contentOwner), 0);
        // Assert that the content pool received some reward
        assertGt(frakToken.balanceOf(address(contentPool)), 0);

        // Claim the founds
        rewarder.withdrawFounds(user);

        // Ensure the founds is withdraw with 2% fees
        assertEq(frakToken.balanceOf(user), availableBalance * 98 / 100);
        assertEq(rewarder.getAvailableFounds(user), 0);
    }

    function test_pay_PayedFraktions_LargeListenCounts_ok() public userWithFraktion {
        RewardListenParam[] memory listenParams = _payParameters(100);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);

        // Assert that the user got some rewards
        assertGt(rewarder.getAvailableFounds(user), 0);
        assertEq(rewarder.getAvailableFounds(user), 252.7 ether);
        // Assert that the owner got some rewards
        assertGt(rewarder.getAvailableFounds(contentOwner), 0);
        // Assert that the content pool received some reward
        assertGt(frakToken.balanceOf(address(contentPool)), 0);
    }

    function test_pay_PayedFraktions_TooMuchListenCounts_ko() public userWithFraktion {
        RewardListenParam[] memory listenParams = _payParameters(301);
        vm.expectRevert(IRewarder.InvalidReward.selector);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);
    }

    function test_pay_InvalidRoles_ko() public {
        RewardListenParam[] memory listenParams = _payParameters();
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payUser(user, 1, listenParams);
        // 2_100_000
    }

    function test_pay_InvalidAddress_ko() public {
        RewardListenParam[] memory listenParams = _payParameters();
        vm.expectRevert(InvalidAddress.selector);
        vm.prank(deployer);
        rewarder.payUser(address(0), 1, listenParams);
    }

    function test_pay_InvalidArray_ko() public {
        RewardListenParam[] memory listenParams = _payParameters();

        listenParams = new RewardListenParam[](0);
        vm.expectRevert(InvalidArray.selector);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);

        listenParams = new RewardListenParam[](21);
        vm.expectRevert(InvalidArray.selector);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);
    }

    function test_pay_InvalidContent_ko() public {
        RewardListenParam[] memory listenParams = _payParameters();
        listenParams[0] = listenParams[0].setContentId(ContentId.wrap(13));

        vm.expectRevert(InvalidAddress.selector);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);
    }

    function test_pay_TooLargeReward_ko() public userWithFraktion {
        RewardListenParam[] memory listenParams = _payParameters(300);
        vm.prank(deployer);
        rewarder.updateListenerBadge(user, 1000 ether);
        vm.prank(deployer);
        rewarder.updateContentBadge(contentId, 1000 ether);

        vm.expectRevert(RewardTooLarge.selector);
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);
    }

    function test_pay_ContentTypeImpact_ok() public {
        RewardListenParam[] memory listenParams = _payParameters();

        // Initial claim balance
        uint256 claimableBalance = rewarder.getAvailableFounds(user);
        uint256 newClaimableBalance = rewarder.getAvailableFounds(user);

        // Ensure it hasn't changes with content type 0 (inexistant)
        vm.prank(deployer);
        rewarder.payUser(user, 0, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertEq(newClaimableBalance - claimableBalance, 0);
        claimableBalance = newClaimableBalance;

        // Ensure the content type 1 has an impact
        vm.prank(deployer);
        rewarder.payUser(user, 1, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertGt(newClaimableBalance - claimableBalance, 0);
        claimableBalance = newClaimableBalance;

        // Ensure the content type 2 has an impact
        vm.prank(deployer);
        rewarder.payUser(user, 2, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertGt(newClaimableBalance - claimableBalance, 0);
        claimableBalance = newClaimableBalance;

        // Ensure the content type 3 has an impact
        vm.prank(deployer);
        rewarder.payUser(user, 3, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertGt(newClaimableBalance - claimableBalance, 0);
        claimableBalance = newClaimableBalance;

        // Ensure the content type 4 has an impact
        vm.prank(deployer);
        rewarder.payUser(user, 4, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertGt(newClaimableBalance - claimableBalance, 0);
        claimableBalance = newClaimableBalance;

        // Ensure the content type 5 has no impact
        vm.prank(deployer);
        rewarder.payUser(user, 5, listenParams);
        newClaimableBalance = rewarder.getAvailableFounds(user);
        assertEq(newClaimableBalance - claimableBalance, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    modifier userWithFraktion() {
        // Build the param for our new content mint, and mint it
        uint256[] memory fTypeArray = new uint256[](4);
        fTypeArray[0] = 3;
        fTypeArray[1] = 4;
        fTypeArray[2] = 5;
        fTypeArray[3] = 6;

        uint256[] memory amounts = new uint256[](fTypeArray.length);
        for (uint256 i = 0; i < fTypeArray.length; i++) {
            amounts[i] = 1;
        }

        FraktionId[] memory fIds = contentId.payableFraktionIds();
        for (uint256 i = 0; i < fIds.length; i++) {
            vm.prank(deployer);
            fraktionTokens.mint(user, fIds[i], 1);
        }

        _;
    }

    function _payParameters() internal view returns (RewardListenParam[] memory) {
        return _payParameters(1);
    }

    function _payParameters(uint256 listenCount) internal view returns (RewardListenParam[] memory listenParams) {
        listenParams = new RewardListenParam[](1);
        listenParams[0] = RewardListenParamLib.build(contentId, uint16(listenCount));
    }
}
