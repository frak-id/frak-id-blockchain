// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { FrakRoles } from "contracts/roles/FrakRoles.sol";
import { ContentPool } from "contracts/reward/contentPool/ContentPool.sol";

/// @dev Testing methods on the ContentPool
contract ContentPoolTest is FrakTest {
    function setUp() public {
        _setupTests();

        // Mint some frk to the content pool
        vm.prank(deployer);
        frakToken.mint(address(contentPool), 1000 ether);

        // Link content pool to the fraktions tokens
        vm.prank(deployer);
        fraktionTokens.registerNewCallback(address(contentPool));

        // Register deployer as rewarder
        vm.prank(deployer);
        contentPool.grantRole(FrakRoles.REWARDER, deployer);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init test's                                */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(ContentPool.initialize, (address(frakToken)));
        address proxyAddress = _deployProxy(address(new ContentPool()), initData, "ContentPoolDeploy");
        contentPool = ContentPool(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        contentPool.initialize(address(frakToken));
    }

    /* -------------------------------------------------------------------------- */
    /*                             Adding reward test                             */
    /* -------------------------------------------------------------------------- */

    function test_addReward_ok() public {
        vm.prank(deployer);
        contentPool.addReward(contentId, 1 ether);
    }

    function test_addReward_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        contentPool.addReward(contentId, 1 ether);
    }

    function test_addReward_InvalidReward_ko() public {
        vm.expectRevert(NoReward.selector);
        vm.prank(deployer);
        contentPool.addReward(contentId, 0);

        vm.expectRevert(NoReward.selector);
        vm.prank(deployer);
        contentPool.addReward(contentId, 100_001 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Updating pool & user state                         */
    /* -------------------------------------------------------------------------- */

    function test_updatePool_ok() public {
        // Simulate fraktion mint by a user
        _mintFraktionByUser();
        _addPoolReward();

        // Compute user rewards & withdraw
        contentPool.computeAllPoolsBalance(user);
        contentPool.withdrawFounds(user);
        // Assert the user received something
        uint256 userBalance = frakToken.balanceOf(user);
        assertGt(userBalance, 0);

        // Add a few more rewards and repeat the process
        _addPoolReward();
        contentPool.withdrawFounds(user);
        assertGt(frakToken.balanceOf(user), userBalance);
        userBalance = frakToken.balanceOf(user);

        // Add a few more rewards and repeat the process
        _addPoolReward();
        vm.prank(user);
        contentPool.withdrawFounds();
        assertGt(frakToken.balanceOf(user), userBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test helper's                               */
    /* -------------------------------------------------------------------------- */

    function _mintFraktionByUser() private {
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 1);
    }

    function _addPoolReward() private {
        vm.prank(deployer);
        contentPool.addReward(contentId, 1 ether);
    }
}
