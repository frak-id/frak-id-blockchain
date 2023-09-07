// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { Rewarder } from "contracts/reward/Rewarder.sol";
import { IRewarder } from "contracts/reward/IRewarder.sol";
import { ContentId } from "contracts/libs/ContentId.sol";

/// @dev Testing the direct payment methods on the Rewarder
contract RewarderDirectPaymentTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                            User direct payment's                           */
    /* -------------------------------------------------------------------------- */

    function test_payUserDirectly() public withFrk(address(rewarder), 10 ether) asDeployer {
        rewarder.payUserDirectly(user, 10 ether);
        assertEq(frakToken.balanceOf(user), 10 ether);
    }

    function test_payUserDirectly_InvalidRole_ko() public withFrk(address(rewarder), 10 ether) {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payUserDirectly(user, 10 ether);
    }

    function test_payUserDirectly_InvalidAddress_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        vm.expectRevert(InvalidAddress.selector);
        rewarder.payUserDirectly(address(0), 10 ether);
    }

    function test_payUserDirectly_InvalidReward_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        vm.expectRevert(IRewarder.InvalidReward.selector);
        rewarder.payUserDirectly(user, 0);

        vm.expectRevert(IRewarder.InvalidReward.selector);
        rewarder.payUserDirectly(user, 1_000_001 ether);
    }

    function test_payUserDirectly_NotEnoughBalance_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        vm.expectRevert();
        rewarder.payUserDirectly(user, 11 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Creator's direct payment                          */
    /* -------------------------------------------------------------------------- */

    function test_payCreatorDirectlyBatch() public withFrk(address(rewarder), 10 ether) asDeployer {
        ContentId[] memory contentIds = new ContentId[](1);
        contentIds[0] = contentId;
        uint256[] memory amountsIds = new uint256[](1);
        amountsIds[0] = 10 ether;

        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_payCreatorDirectlyBatch_InvalidRole_ko() public withFrk(address(rewarder), 10 ether) {
        ContentId[] memory contentIds = new ContentId[](1);
        contentIds[0] = contentId;
        uint256[] memory amountsIds = new uint256[](1);
        amountsIds[0] = 10 ether;

        vm.expectRevert(NotAuthorized.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_payCreatorDirectlyBatch_InvalidArray_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        ContentId[] memory contentIds = new ContentId[](3);
        uint256[] memory amountsIds = new uint256[](4);

        vm.expectRevert(InvalidArray.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_payCreatorDirectlyBatch_TooLargeArray_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        ContentId[] memory contentIds = new ContentId[](21);
        uint256[] memory amountsIds = new uint256[](21);

        vm.expectRevert(InvalidArray.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_payCreatorDirectlyBatch_EmptyAmount_ko() public withFrk(address(rewarder), 10 ether) asDeployer {
        ContentId[] memory contentIds = new ContentId[](1);
        contentIds[0] = contentId;
        uint256[] memory amountsIds = new uint256[](1);

        vm.expectRevert(IRewarder.InvalidReward.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_payCreatorDirectlyBatch_TooLargeAmount_ko()
        public
        withFrk(address(rewarder), 2_000_000 ether)
        asDeployer
    {
        ContentId[] memory contentIds = new ContentId[](1);
        contentIds[0] = contentId;
        uint256[] memory amountsIds = new uint256[](1);
        amountsIds[0] = 1_000_001 ether;

        vm.expectRevert(IRewarder.InvalidReward.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }
}
