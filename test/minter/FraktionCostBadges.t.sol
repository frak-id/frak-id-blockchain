// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { InvalidFraktionType, NotAuthorized } from "contracts/utils/FrakErrors.sol";
import { ContentId, ContentIdLib } from "contracts/libs/ContentId.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";

/// @dev Testing methods on the FraktionCostBadges
contract FraktionCostBadgesTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Default prices test                            */
    /* -------------------------------------------------------------------------- */

    function test_defaultPrice_ok() public {
        assertEq(minter.getCostBadge(contentId.commonFraktionId()), 90 ether);
        assertEq(minter.getCostBadge(contentId.premiumFraktionId()), 500 ether);
        assertEq(minter.getCostBadge(contentId.goldFraktionId()), 1200 ether);
        assertEq(minter.getCostBadge(contentId.diamondFraktionId()), 3000 ether);
    }

    function test_defaultPrice_InvalidFraktionType_ko() public {
        vm.expectRevert(InvalidFraktionType.selector);
        minter.getCostBadge(contentId.freeFraktionId());

        vm.expectRevert(InvalidFraktionType.selector);
        minter.getCostBadge(contentId.creatorFraktionId());

        vm.expectRevert(InvalidFraktionType.selector);
        minter.getCostBadge(contentId.toFraktionId(0));

        vm.expectRevert(InvalidFraktionType.selector);
        minter.getCostBadge(contentId.toFraktionId(7));
    }

    /* -------------------------------------------------------------------------- */
    /*                                Price update                                */
    /* -------------------------------------------------------------------------- */

    function test_updatePrice_ok() public {
        // Update the badge cost of the specified fraktionId
        vm.startPrank(deployer);
        minter.updateCostBadge(contentId.commonFraktionId(), 100 ether);
        minter.updateCostBadge(contentId.premiumFraktionId(), 600 ether);
        minter.updateCostBadge(contentId.goldFraktionId(), 1300 ether);
        minter.updateCostBadge(contentId.diamondFraktionId(), 3100 ether);
        vm.stopPrank();

        // Ensure, the badge cost are ok
        assertEq(minter.getCostBadge(contentId.commonFraktionId()), 100 ether);
        assertEq(minter.getCostBadge(contentId.premiumFraktionId()), 600 ether);
        assertEq(minter.getCostBadge(contentId.goldFraktionId()), 1300 ether);
        assertEq(minter.getCostBadge(contentId.diamondFraktionId()), 3100 ether);
    }

    function test_updatePrice_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.updateCostBadge(contentId.commonFraktionId(), 100 ether);
    }

    function test_updatePrice_InvalidFraktionType_ko() public asDeployer {
        vm.expectRevert(InvalidFraktionType.selector);
        minter.updateCostBadge(contentId.freeFraktionId(), 1);

        vm.expectRevert(InvalidFraktionType.selector);
        minter.updateCostBadge(contentId.creatorFraktionId(), 1);

        vm.expectRevert(InvalidFraktionType.selector);
        minter.updateCostBadge(contentId.toFraktionId(0), 1);

        vm.expectRevert(InvalidFraktionType.selector);
        minter.updateCostBadge(contentId.toFraktionId(7), 1);
    }
}
