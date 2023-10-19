// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import {
    NotAuthorized,
    InvalidAddress,
    NoReward,
    RewardTooLarge,
    InvalidArray,
    BadgeTooLarge
} from "contracts/utils/FrakErrors.sol";
import { Rewarder } from "contracts/reward/Rewarder.sol";
import { IRewarder } from "contracts/reward/IRewarder.sol";
import { ContentId } from "contracts/libs/ContentId.sol";

/// @dev Testing the config methods on the Rewarder
contract RewarderConfigTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(
            Rewarder.initialize,
            (address(frakToken), address(fraktionTokens), address(contentPool), address(referralPool), foundation)
        );
        address proxyAddress = _deployProxy(address(new Rewarder()), initData, "RewarderDeploy");
        rewarder = Rewarder(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize(
            address(frakToken), address(fraktionTokens), address(contentPool), address(referralPool), foundation
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                     Tpu                                    */
    /* -------------------------------------------------------------------------- */

    function test_updateTpu_ok() public {
        vm.prank(deployer);
        rewarder.updateTpu(2 ether);

        assertEq(rewarder.getTpu(), 2 ether);
    }

    function test_updateTpu_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateTpu(2 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Content badges                               */
    /* -------------------------------------------------------------------------- */

    function test_updateContentBadge_ok() public {
        // Test initial value
        assertEq(rewarder.getContentBadge(contentId), 1 ether);

        // Update the badge
        vm.prank(deployer);
        rewarder.updateContentBadge(contentId, 2 ether);

        assertEq(rewarder.getContentBadge(contentId), 2 ether);
    }

    function test_updateContentBadge_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_updateContentBadge_BadgeTooLarge_ko() public {
        vm.expectRevert(BadgeTooLarge.selector);
        vm.prank(deployer);
        rewarder.updateContentBadge(contentId, 1001 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Listener badges                              */
    /* -------------------------------------------------------------------------- */

    function test_updateListenerBadge_ok() public {
        // Test initial value
        assertEq(rewarder.getListenerBadge(user), 1 ether);

        // Update the badge
        vm.prank(deployer);
        rewarder.updateListenerBadge(user, 2 ether);

        assertEq(rewarder.getListenerBadge(user), 2 ether);
    }

    function test_updateListenerBadge_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateListenerBadge(user, 2 ether);
    }

    function test_updateListenerBadge_BadgeTooLarge_ko() public {
        vm.expectRevert(BadgeTooLarge.selector);
        vm.prank(deployer);
        rewarder.updateListenerBadge(user, 1001 ether);
    }
}
