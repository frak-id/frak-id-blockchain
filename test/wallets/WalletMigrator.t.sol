// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/console.sol";
import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { FrakTreasuryWallet, NotEnoughTreasury } from "contracts/wallets/FrakTreasuryWallet.sol";
import { WalletMigrator } from "contracts/wallets/WalletMigrator.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";
import { ContentId } from "contracts/libs/ContentId.sol";

/// @dev Testing methods on the WalletMigrator
contract WalletMigratorTest is FrakTest {
    WalletMigrator walletMigrator;
    address targetUser;

    function setUp() public {
        _setupTests();

        // The user that will receive the migration result
        targetUser = _newUser("migrationTargetUser");

        // Build the wallet migrator we will test
        walletMigrator = new WalletMigrator(
            address(frakToken), 
            address(fraktionTokens), 
            address(rewarder), 
            address(contentPool), 
            address(referralPool)
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                            Test claim all founds                           */
    /* -------------------------------------------------------------------------- */

    function test_claimAllFounds_ok() public withUserReward {
        vm.prank(user);
        walletMigrator.claimAllFounds();

        // Ensure all the reward as been claimed
        _assertRewardClaimed();
    }

    function test_claimAllFoundsForUser_ok() public withUserReward {
        walletMigrator.claimAllFounds(user);

        // Ensure all the reward as been claimed
        _assertRewardClaimed();
    }

    function _assertRewardClaimed() internal {
        assertGt(frakToken.balanceOf(user), 0);
        assertEq(rewarder.getAvailableFounds(user), 0);
        assertEq(contentPool.getAvailableFounds(user), 0);
        assertEq(referralPool.getAvailableFounds(user), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test frak transfer                             */
    /* -------------------------------------------------------------------------- */

    function test_migrateFrk_ok() public withFrk(user, 10 ether) {
        // Generate the permit signature for the wallet migration
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) =
            _generateUserPermitSignature(address(walletMigrator), type(uint256).max, deadline);

        // Perform the migration
        vm.prank(user);
        walletMigrator.migrateFrk(targetUser, deadline, v, r, s);

        // Ensure all the frk are migrated
        _assertFrkTransfered(10 ether);
    }

    function test_migrateFrkForUser_ok() public withFrk(user, 10 ether) {
        // Generate the permit signature for the wallet migration
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) =
            _generateUserPermitSignature(address(walletMigrator), type(uint256).max, deadline);

        // Perform the migration
        walletMigrator.migrateFrk(user, targetUser, deadline, v, r, s);

        // Ensure all the frk are migrated
        _assertFrkTransfered(10 ether);
    }

    function _assertFrkTransfered(uint256 amount) internal {
        assertEq(frakToken.balanceOf(targetUser), amount);
        assertEq(frakToken.balanceOf(user), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Test fraktion transfer                           */
    /* -------------------------------------------------------------------------- */

    function test_migrateFrations_ok() public userWithAllFraktions {
        // Generate the permit signature for the wallet migration
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitTransferAllSignature(address(walletMigrator), deadline);

        // Perform the migration
        vm.prank(user);
        walletMigrator.migrateFraktions(targetUser, deadline, v, r, s, _allFraktionsIds());

        // Ensure every fraktion type is well transfered
        _assertFraktionTransfered();
    }

    function test_migrateFrationsForUser_ok() public userWithAllFraktions {
        // Generate the permit signature for the wallet migration
        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitTransferAllSignature(address(walletMigrator), deadline);

        // Perform the migration
        walletMigrator.migrateFraktions(user, targetUser, deadline, v, r, s, _allFraktionsIds());

        // Ensure every fraktion type is well transfered
        _assertFraktionTransfered();
    }

    /// @dev Check that every fraktion type is transfered
    function _assertFraktionTransfered() internal {
        // Ensure every fraktion type is well transfered
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.commonFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.premiumFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.goldFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.diamondFraktionId())), 0);

        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.commonFraktionId())), 5);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.premiumFraktionId())), 2);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.goldFraktionId())), 1);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.diamondFraktionId())), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal helper functions                         */
    /* -------------------------------------------------------------------------- */

    modifier withUserReward() {
        vm.startPrank(deployer);
        // Mint a few frak to the rewarder
        frakToken.mint(address(rewarder), 100_000 ether);

        // Mint a fraktion to our user
        fraktionTokens.mint(user, contentId.goldFraktionId(), 1);

        // Then pay it multiple time on this content
        ContentId[] memory contentIds = new ContentId[](1);
        contentIds[0] = contentId;
        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = 300;
        rewarder.payUser(user, 1, contentIds, listenCounts);
        rewarder.payUser(user, 1, contentIds, listenCounts);
        rewarder.payUser(user, 1, contentIds, listenCounts);
        rewarder.payUser(user, 1, contentIds, listenCounts);
        vm.stopPrank();
        _;
    }

    modifier userWithAllFraktions() {
        // A few fraktion to the users
        vm.startPrank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 5);
        fraktionTokens.mint(user, contentId.premiumFraktionId(), 2);
        fraktionTokens.mint(user, contentId.goldFraktionId(), 1);
        fraktionTokens.mint(user, contentId.diamondFraktionId(), 1);
        vm.stopPrank();
        _;
    }

    function _allFraktionsIds() internal view returns (uint256[] memory fraktionIds) {
        fraktionIds = new uint256[](4);
        fraktionIds[0] = FraktionId.unwrap(contentId.commonFraktionId());
        fraktionIds[1] = FraktionId.unwrap(contentId.premiumFraktionId());
        fraktionIds[2] = FraktionId.unwrap(contentId.goldFraktionId());
        fraktionIds[3] = FraktionId.unwrap(contentId.diamondFraktionId());
    }
}
