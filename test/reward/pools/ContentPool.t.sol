// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { FrakRoles } from "contracts/roles/FrakRoles.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";
import { ContentId } from "contracts/libs/ContentId.sol";
import { ContentPool } from "contracts/reward/contentPool/ContentPool.sol";
import { IContentPool } from "contracts/reward/contentPool/IContentPool.sol";

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

    function test_updateUserAndPool_ok() public {
        // Simulate fraktion mint by a user
        _mintCommonForUser();
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

        // Handle the case of a fraktion burn
        vm.prank(user);
        fraktionTokens.burn(contentId.commonFraktionId(), 1);

        // Add a few more rewards but ensure the user hasn't got any share remaining
        _addPoolReward();
        vm.prank(user);
        contentPool.withdrawFounds();
        assertEq(frakToken.balanceOf(user), userBalance);
    }

    function test_updateUserAndPool_WithRewardBeforeState_ok() public {
        // Simulate fraktion mint by a user
        _addPoolReward();
        _mintCommonForUser();

        // Compute user rewards & withdraw
        contentPool.computeAllPoolsBalance(user);
        contentPool.withdrawFounds(user);
        // Assert the user received something
        uint256 userBalance = frakToken.balanceOf(user);
        assertGt(userBalance, 0);

        // Add a few more rewards and repeat the process
        _addPoolReward();
        _mintPremiumForUser();
        contentPool.withdrawFounds(user);
        assertGt(frakToken.balanceOf(user), userBalance);
        userBalance = frakToken.balanceOf(user);

        // Add a few more rewards and repeat the process
        _addPoolReward();
        vm.prank(user);
        fraktionTokens.burn(contentId.commonFraktionId(), 1);

        vm.prank(user);
        contentPool.withdrawFounds();
        assertGt(frakToken.balanceOf(user), userBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Updating user state                            */
    /* -------------------------------------------------------------------------- */

    function test_updateUser_ok() public {
        // Simulate fraktion mint by a user
        _mintCommonForUser();
        _addPoolReward();

        address targetUser = _newUser("contentPoolTargetUser");

        // Compute user rewards & withdraw
        contentPool.computeAllPoolsBalance(user);
        contentPool.withdrawFounds(user);
        // Assert the user received something
        uint256 userBalance = frakToken.balanceOf(user);
        assertGt(userBalance, 0);

        // Transfer the user fraktion to the target user
        vm.prank(user);
        fraktionTokens.safeTransferFrom(user, targetUser, FraktionId.unwrap(contentId.commonFraktionId()), 1, "");

        // Add a few more rewards and repeat the process
        _addPoolReward();
        contentPool.withdrawFounds(user);
        contentPool.withdrawFounds(targetUser);
        assertEq(frakToken.balanceOf(user), userBalance);
        assertGt(frakToken.balanceOf(targetUser), 0);
        assertEq(frakToken.balanceOf(targetUser), userBalance);
    }

    function test_updateUser_WithRewardBeforeStateChange_ok() public {
        // Simulate fraktion mint by a user
        _mintCommonForUser();
        _addPoolReward();

        address targetUser = _newUser("contentPoolTargetUser");

        // Compute user rewards & withdraw
        contentPool.computeAllPoolsBalance(user);
        contentPool.withdrawFounds(user);
        // Assert the user received something
        uint256 userBalance = frakToken.balanceOf(user);
        uint256 targetUserBalance = frakToken.balanceOf(targetUser);
        assertGt(userBalance, 0);
        assertEq(targetUserBalance, 0);

        // Transfer the user fraktion to the target user
        _addPoolReward();
        vm.prank(user);
        fraktionTokens.safeTransferFrom(user, targetUser, FraktionId.unwrap(contentId.commonFraktionId()), 1, "");
        _addPoolReward();

        // Add a few more rewards and repeat the process
        contentPool.withdrawFounds(user);
        contentPool.withdrawFounds(targetUser);
        assertGt(frakToken.balanceOf(user), userBalance);
        assertGt(frakToken.balanceOf(targetUser), targetUserBalance);
        assertEq(frakToken.balanceOf(targetUser), userBalance);
        userBalance = frakToken.balanceOf(user);
        targetUserBalance = frakToken.balanceOf(targetUser);

        // Ensure we can can mint some other fraktion and the user will receive more
        _mintPremiumForUser();
        _mintGoldForUser();
        _mintDiamondForUser();
        _addPoolReward();

        // So user has 50 + 100 + 200 = 350 shares
        // And target user a only 10
        // So the ratio of the reward should be 35:1
        // Total shares is 360
        // So the user should receive 350/360 * 100 = 97.22
        // And the target user 10/360 * 100 = 2.77

        // Withdraw the founds for both user
        contentPool.withdrawFounds(user);
        contentPool.withdrawFounds(targetUser);

        // Ensure the balance changes
        uint256 userBalanceChange = frakToken.balanceOf(user) - userBalance;
        uint256 targetUserBalanceChange = frakToken.balanceOf(targetUser) - targetUserBalance;
        assertGt(userBalanceChange, 0);
        assertGt(targetUserBalanceChange, 0);
        assertGt(userBalanceChange, targetUserBalanceChange);
        assertEq(userBalanceChange / targetUserBalanceChange, 35);
        // Ensure amount received
        assertAlmostEq(userBalanceChange + targetUserBalanceChange, 100 ether, 1);
        // Get the participant share and ensure it's valid
        IContentPool.Participant memory userParticipant =
            contentPool.getParticipantForContent(ContentId.unwrap(contentId), user);
        IContentPool.Participant memory targetUserParticipant =
            contentPool.getParticipantForContent(ContentId.unwrap(contentId), targetUser);
        // Ensure the ratio is correct
        assertEq(userParticipant.shares, 350);
        assertEq(targetUserParticipant.shares, 10);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test view function                             */
    /* -------------------------------------------------------------------------- */

    function test_participantStates_ok() public {
        _mintCommonForUser();
        IContentPool.ParticipantInPoolState[] memory participantStates = contentPool.getParticipantStates(user);

        assertEq(participantStates.length, 1);
        assertEq(participantStates[0].poolId, ContentId.unwrap(contentId));
        assertEq(participantStates[0].totalShares, 10);
        assertEq(participantStates[0].poolState, 0);
        assertEq(participantStates[0].shares, 10);
        assertEq(participantStates[0].lastStateClaimed, 0);
        assertEq(participantStates[0].lastStateIndex, 0);
    }

    function test_getRewardStates_ok() public {
        _addPoolReward();
        _mintCommonForUser();

        IContentPool.RewardState[] memory rewardStates = contentPool.getAllRewardStates(ContentId.unwrap(contentId));

        assertEq(rewardStates.length, 1);
        assertEq(rewardStates[0].totalShares, 10);
        assertEq(rewardStates[0].currentPoolReward, 100 ether);
        assertEq(rewardStates[0].open, true);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test helper's                               */
    /* -------------------------------------------------------------------------- */

    function _mintCommonForUser() private {
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 1);
    }

    function _mintPremiumForUser() private {
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.premiumFraktionId(), 1);
    }

    function _mintGoldForUser() private {
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.goldFraktionId(), 1);
    }

    function _mintDiamondForUser() private {
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.diamondFraktionId(), 1);
    }

    function _addPoolReward() private {
        vm.prank(deployer);
        contentPool.addReward(contentId, 100 ether);
    }
}
