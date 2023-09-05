// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakToken } from "@frak/tokens/FrakToken.sol";
import { ArrayLib } from "@frak/libs/ArrayLib.sol";
import {
    MultiVestingWallets, NotEnoughFounds, InvalidDuration, InvalidDate
} from "@frak/wallets/MultiVestingWallets.sol";
import { FrkTokenTestHelper } from "../FrkTokenTestHelper.sol";
import {
    NotAuthorized,
    InvalidArray,
    InvalidAddress,
    NoReward,
    ContractPaused,
    RewardTooLarge
} from "@frak/utils/FrakErrors.sol";

/// Testing the frak l2 token
contract MultiVestingWalletsTest is FrkTokenTestHelper {
    using ArrayLib for address;
    using ArrayLib for uint256;

    address multiVestingAddr;
    MultiVestingWallets vestingWallets;

    function setUp() public {
        _setupFrkToken();

        // Deploy our multi vesting wallets
        bytes memory initData = abi.encodeCall(MultiVestingWallets.initialize, (address(frakToken)));
        multiVestingAddr = deployContract(address(new MultiVestingWallets()), initData);
        vestingWallets = MultiVestingWallets(multiVestingAddr);
    }

    /*
     * ===== TEST : initialize(address tokenAddr) =====
     */
    function test_fail_initialize_CantInitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        vestingWallets.initialize(address(0));
    }

    /*
     * ===== TEST : name() =====
     */
    function test_name() public {
        assertEq(vestingWallets.name(), "Vested FRK Token");
    }

    /*
     * ===== TEST : decimals() =====
     */
    function test_decimals() public {
        assertEq(vestingWallets.decimals(), 18);
    }

    /*
     * ===== TEST : symbol() =====
     */
    function test_symbol() public {
        assertEq(vestingWallets.symbol(), "vFRK");
    }

    /*
     * ===== TEST : availableReserve() =====
     */
    function test_availableReserve() public {
        assertEq(vestingWallets.availableReserve(), 0);
        prankDeployer();
        frakToken.mint(multiVestingAddr, 1);
        assertEq(vestingWallets.availableReserve(), 1);
        assertEq(vestingWallets.availableReserve(), frakToken.balanceOf(multiVestingAddr));
    }

    /*
     * ===== TEST : transferAvailableReserve(address receiver) =====
     */
    function test_transferAvailableReserve() public withFrkToken(multiVestingAddr) {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.transferAvailableReserve(address(1));
        assertEq(vestingWallets.availableReserve(), 0);
        assertEq(frakToken.balanceOf(address(1)), 10);
    }

    function test_fail_transferAvailableReserve_NotAdmin() public withFrkToken(multiVestingAddr) {
        // Ask to transfer the available reserve
        vm.expectRevert(NotAuthorized.selector);
        vestingWallets.transferAvailableReserve(address(1));
    }

    function test_fail_transferAvailableReserve_ContractPaused() public withFrkToken(multiVestingAddr) {
        prankDeployer();
        vestingWallets.pause();

        // Ask to transfer the available reserve
        vm.expectRevert(ContractPaused.selector);
        vestingWallets.transferAvailableReserve(address(1));
    }

    function test_fail_TransferAvailableReserve_NoReserve() public {
        // Ask to transfer the available reserve
        vm.expectRevert(NoReward.selector);
        prankDeployer();
        vestingWallets.transferAvailableReserve(address(1));
    }

    /*
     * ===== TEST : createVest(
        address beneficiary,
        uint256 amount,
        uint32 duration,
        uint48 startDate
    ) =====
     */
    function test_createVest() public withFrkToken(multiVestingAddr) {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
        assertEq(vestingWallets.balanceOf(address(1)), 10);
    }

    function test_fail_createVest_NotManager() public withFrkToken(multiVestingAddr) {
        vm.expectRevert(NotAuthorized.selector);
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_ContractPaused() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vestingWallets.pause();
        vm.expectRevert(ContractPaused.selector);
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_InvalidDuration() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidDuration.selector);
        vestingWallets.createVest(address(1), 10, 0, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_InvalidStartDate() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidDate.selector);
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp - 1));
    }

    function test_fail_createVest_InvalidStartDateTooFar() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidDate.selector);
        vestingWallets.createVest(address(1), 10, 10, 2_525_644_801);
    }

    function test_fail_createVest_NotEnoughReserve() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(NotEnoughFounds.selector);
        vestingWallets.createVest(address(1), 11, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_InvalidAddress() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidAddress.selector);
        vestingWallets.createVest(address(0), 10, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_InvalidReward() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(NoReward.selector);
        vestingWallets.createVest(address(10), 0, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVest_TooLargeReward() public withLotFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(RewardTooLarge.selector);
        vestingWallets.createVest(address(10), 200_000_001 ether, 10, uint48(block.timestamp + 1));
    }

    /*
     * ===== createVestBatch(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint32 duration,
        uint48 startDate
    ) =====
     */
    function test_createVestBatch() public withFrkToken(multiVestingAddr) {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(), uint256(10).asSingletonArray(), 10, uint48(block.timestamp + 1)
        );
        assertEq(vestingWallets.balanceOf(address(1)), 10);
    }

    function test_fail_createVestBatch_NotManager() public withFrkToken(multiVestingAddr) {
        vm.expectRevert(NotAuthorized.selector);
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(), uint256(10).asSingletonArray(), 10, uint48(block.timestamp + 1)
        );
    }

    function test_fail_createVestBatch_ContractPaused() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vestingWallets.pause();

        vm.expectRevert(ContractPaused.selector);
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(), uint256(10).asSingletonArray(), 10, uint48(block.timestamp + 1)
        );
    }

    function test_fail_createVestBatch_NotEnoughReserve() public withFrkToken(multiVestingAddr) prankExecAsDeployer {
        vm.expectRevert(NotEnoughFounds.selector);
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(), uint256(11).asSingletonArray(), 10, uint48(block.timestamp + 1)
        );
    }

    function test_fail_createVestBatch_EmptyArray() public withFrkToken(multiVestingAddr) {
        address[] memory addresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        prankDeployer();

        vm.expectRevert(InvalidArray.selector);
        vestingWallets.createVestBatch(addresses, amounts, 10, uint48(block.timestamp + 1));
    }

    function test_fail_createVestBatch_ArrayInvalidLength() public withFrkToken(multiVestingAddr) {
        address[] memory addresses = new address[](0);
        prankDeployer();

        vm.expectRevert(InvalidArray.selector);
        vestingWallets.createVestBatch(addresses, uint256(10).asSingletonArray(), 10, uint48(block.timestamp + 1));
    }

    /*
     * ===== TEST : transfer(address to, uint24 vestingId) =====
     */
    function test_transfer() public withFrkToken(multiVestingAddr) {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
        assertEq(vestingWallets.balanceOf(address(1)), 10);
        // Ask to transfer the vesting
        vm.prank(address(1));
        vestingWallets.transfer(address(2), 0);
    }
}
