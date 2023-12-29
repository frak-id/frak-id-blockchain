// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidArray, InvalidAddress, NoReward, RewardTooLarge } from "contracts/utils/FrakErrors.sol";
import {
    MultiVestingWallets,
    NotEnoughFounds,
    InvalidDuration,
    InvalidDate
} from "contracts/wallets/MultiVestingWallets.sol";

/// @dev Testing methods on the MultiVestingWallets
contract MultiVestingWalletsTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(MultiVestingWallets.initialize, (address(frakToken)));
        address proxyAddress = _deployProxy(address(new MultiVestingWallets()), initData, "MultiVestingWalletsDeploy");
        multiVestingWallet = MultiVestingWallets(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        multiVestingWallet.initialize(address(frakToken));
    }

    /* -------------------------------------------------------------------------- */
    /*                         Some global properties test                        */
    /* -------------------------------------------------------------------------- */

    function test_name_ok() public {
        assertEq(multiVestingWallet.name(), "Vested FRK Token");
    }

    function test_decimals_ok() public {
        assertEq(multiVestingWallet.decimals(), 18);
    }

    function test_symbol_ok() public {
        assertEq(multiVestingWallet.symbol(), "vFRK");
    }

    /* -------------------------------------------------------------------------- */
    /*                              Vesting creation                              */
    /* -------------------------------------------------------------------------- */

    function test_createVest_ok() public withFrk(address(multiVestingWallet), 10 ether) {
        // Ask to transfer the available reserve
        vm.prank(deployer);
        multiVestingWallet.createVest(user, 10, 10, uint48(block.timestamp + 1));
        assertEq(multiVestingWallet.balanceOf(user), 10);
    }

    function test_createVest_NotManager_ko() public withFrk(address(multiVestingWallet), 10 ether) {
        vm.expectRevert(NotAuthorized.selector);
        multiVestingWallet.createVest(user, 10, 10, uint48(block.timestamp + 1));
    }

    function test_createVest_InvalidDuration_ko() public withFrk(address(multiVestingWallet), 10 ether) asDeployer {
        vm.expectRevert(InvalidDuration.selector);
        multiVestingWallet.createVest(user, 10, 0, uint48(block.timestamp + 1));
    }

    function test_createVest_InvalidStartDate_ko() public withFrk(address(multiVestingWallet), 10 ether) asDeployer {
        vm.expectRevert(InvalidDate.selector);
        multiVestingWallet.createVest(user, 10, 10, uint48(block.timestamp - 1));
    }

    function test_createVest_InvalidStartDateTooFar_ko()
        public
        withFrk(address(multiVestingWallet), 10 ether)
        asDeployer
    {
        vm.expectRevert(InvalidDate.selector);
        multiVestingWallet.createVest(user, 10, 10, 2_525_644_801);
    }

    function test_createVest_NotEnoughReserve_ko() public withFrk(address(multiVestingWallet), 10 ether) asDeployer {
        vm.expectRevert(NotEnoughFounds.selector);
        multiVestingWallet.createVest(user, 11 ether, 10, uint48(block.timestamp + 1));
    }

    function test_createVest_InvalidAddress_ko() public withFrk(address(multiVestingWallet), 10 ether) asDeployer {
        vm.expectRevert(InvalidAddress.selector);
        multiVestingWallet.createVest(address(0), 10, 10, uint48(block.timestamp + 1));
    }

    function test_createVest_InvalidReward_ko() public withFrk(address(multiVestingWallet), 10 ether) asDeployer {
        vm.expectRevert(NoReward.selector);
        multiVestingWallet.createVest(address(10), 0, 10, uint48(block.timestamp + 1));
    }

    function test_createVest_TooLargeReward_ko()
        public
        withFrk(address(multiVestingWallet), 300_000_000 ether)
        asDeployer
    {
        vm.expectRevert(RewardTooLarge.selector);
        multiVestingWallet.createVest(address(10), 200_000_001 ether, 10, uint48(block.timestamp + 1));
    }

    function test_createVestBatch() public withFrk(address(multiVestingWallet), 10 ether) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;
        address[] memory addresses = new address[](1);
        addresses[0] = user;

        // Ask to transfer the available reserve
        vm.prank(deployer);
        multiVestingWallet.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
        assertEq(multiVestingWallet.balanceOf(user), 10);
    }

    function test_createVestBatch_NotManager_ko() public withFrk(address(multiVestingWallet), 10 ether) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;
        address[] memory addresses = new address[](1);
        addresses[0] = user;

        vm.expectRevert(NotAuthorized.selector);
        multiVestingWallet.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
    }

    function test_createVestBatch_NotEnoughReserve_ko()
        public
        withFrk(address(multiVestingWallet), 10 ether)
        asDeployer
    {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 11 ether;
        address[] memory addresses = new address[](1);
        addresses[0] = user;

        vm.expectRevert(NotEnoughFounds.selector);
        multiVestingWallet.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
    }

    function test_createVestBatch_EmptyArray_ko() public withFrk(address(multiVestingWallet), 10 ether) {
        address[] memory addresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(deployer);
        vm.expectRevert(InvalidArray.selector);
        multiVestingWallet.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
    }

    function test_createVestBatch_ArrayInvalidLength_ko() public withFrk(address(multiVestingWallet), 10 ether) {
        uint256[] memory amounts = new uint256[](1);
        address[] memory addresses = new address[](0);

        vm.prank(deployer);
        vm.expectRevert(InvalidArray.selector);
        multiVestingWallet.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Test veting lifecycle                           */
    /* -------------------------------------------------------------------------- */

    function test_transfer_ok() public withUserVesting {
        address targetUser = _newUser("transferTargetUser");
        assertEq(multiVestingWallet.balanceOf(user), 10 ether);

        vm.prank(user);
        multiVestingWallet.transfer(targetUser, 0);

        assertEq(multiVestingWallet.balanceOf(targetUser), 10 ether);
    }

    function test_transfer_InvalidUser_ko() public withUserVesting {
        address targetUser = _newUser("transferTargetUser");

        vm.expectRevert(NotAuthorized.selector);
        multiVestingWallet.transfer(targetUser, 0);
    }

    function test_transfer_InvalidAddress_ko() public withUserVesting {
        vm.prank(user);
        vm.expectRevert(InvalidAddress.selector);
        multiVestingWallet.transfer(address(0), 0);
    }

    function test_release_ok() public withUserVesting {
        // Nothing to release just after the creation
        assertEq(multiVestingWallet.releasableAmount(0), 0);
        assertEq(multiVestingWallet.vestedAmount(0), 0);
        assertEq(multiVestingWallet.balanceOfVesting(0), 10 ether);
        assertEq(multiVestingWallet.ownedCount(user), 1);

        // Jump in the futur
        vm.warp(block.timestamp + 1000);

        // Assert all is releasable
        assertEq(multiVestingWallet.releasableAmount(0), 10 ether);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);

        // Release all
        vm.prank(user);
        multiVestingWallet.release(0);

        // ASsert the balance has increase
        assertEq(frakToken.balanceOf(user), 10 ether);
        assertEq(multiVestingWallet.releasableAmount(0), 0);
        assertEq(multiVestingWallet.balanceOfVesting(0), 0);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);
    }

    function test_releaseAll_ok() public withUserVesting {
        // Jump in the futur
        vm.warp(block.timestamp + 1000);

        // Assert all is releasable
        assertEq(multiVestingWallet.releasableAmount(0), 10 ether);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);

        // Release all
        vm.prank(user);
        multiVestingWallet.releaseAll();

        // ASsert the balance has increase
        assertEq(frakToken.balanceOf(user), 10 ether);
        assertEq(multiVestingWallet.releasableAmount(0), 0);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);
    }

    function test_releaseAllForUser_ok() public withUserVesting {
        vm.prank(user);
        vm.expectRevert(NoReward.selector);
        multiVestingWallet.releaseAllFor(user);

        // Jump in the futur
        vm.warp(block.timestamp + 1000);

        // Assert all is releasable
        assertEq(multiVestingWallet.releasableAmount(0), 10 ether);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);

        // Release all
        multiVestingWallet.releaseAllFor(user);

        // ASsert the balance has increase
        assertEq(frakToken.balanceOf(user), 10 ether);
        assertEq(multiVestingWallet.releasableAmount(0), 0);
        assertEq(multiVestingWallet.vestedAmount(0), 10 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Reserve managment                             */
    /* -------------------------------------------------------------------------- */

    function test_transferReserve_ok() public {
        assertEq(multiVestingWallet.availableReserve(), 0);

        vm.prank(deployer);
        vm.expectRevert(NoReward.selector);
        multiVestingWallet.transferAvailableReserve(user);

        // Mint some token to our vesting wallet
        vm.prank(deployer);
        frakToken.mint(address(multiVestingWallet), 10 ether);

        assertEq(multiVestingWallet.availableReserve(), 10 ether);

        // Try to transfer them
        vm.prank(deployer);
        multiVestingWallet.transferAvailableReserve(user);

        assertEq(multiVestingWallet.availableReserve(), 0);
        assertEq(frakToken.balanceOf(user), 10 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test helpers                                */
    /* -------------------------------------------------------------------------- */

    modifier withUserVesting() {
        // Mint some token to our vesting wallet
        vm.prank(deployer);
        frakToken.mint(address(multiVestingWallet), 10 ether);
        // Create a vesting for our user
        vm.prank(deployer);
        multiVestingWallet.createVest(user, 10 ether, 10, uint48(block.timestamp + 1));
        _;
    }
}
