// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { FrakTreasuryWallet, NotEnoughTreasury } from "contracts/wallets/FrakTreasuryWallet.sol";

/// @dev Testing methods on the FrakTeasuryWallet
contract FrakTeasuryWalletTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(FrakTreasuryWallet.initialize, (address(frakToken)));
        address proxyAddress = _deployProxy(address(new FrakTreasuryWallet()), initData, "FrakTreasuryWalletDeploy");
        treasuryWallet = FrakTreasuryWallet(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        treasuryWallet.initialize(address(frakToken));
    }

    /* -------------------------------------------------------------------------- */
    /*                                Transfer test                               */
    /* -------------------------------------------------------------------------- */
    function test_transfer_ok() public {
        vm.prank(deployer);
        treasuryWallet.transfer(user, 1 ether);

        assertEq(frakToken.balanceOf(user), 1 ether);
        assertEq(frakToken.balanceOf(address(treasuryWallet)) > 0, true);
    }

    function test_transfer_NotMinter_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        treasuryWallet.transfer(user, 1 ether);
    }

    function test_transfer_InvalidAddress_ko() public asDeployer {
        vm.expectRevert(InvalidAddress.selector);
        treasuryWallet.transfer(address(0), 1 ether);
    }

    function test_transfer_NoReward_ko() public asDeployer {
        vm.expectRevert(NoReward.selector);
        treasuryWallet.transfer(user, 0);
    }

    function test_transfer_RewardTooLarge_ko() public asDeployer {
        vm.expectRevert(RewardTooLarge.selector);
        treasuryWallet.transfer(user, 500_001 ether);
    }

    function test_transfer_NotEnoughTreasury_ko() public asDeployer {
        uint256 totalToTransfer = 330_000_000 ether;
        uint256 iteration = 500_000 ether;

        do {
            treasuryWallet.transfer(user, iteration);
            totalToTransfer -= iteration;
        } while (totalToTransfer > 0);

        vm.expectRevert(NotEnoughTreasury.selector);
        treasuryWallet.transfer(user, iteration);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Transfer batch                               */
    /* -------------------------------------------------------------------------- */

    function test_transferBatch_ok() public {
        (address[] memory addrs, uint256[] memory amounts) = _baseBatchTransferParam(1 ether);
        vm.prank(deployer);
        treasuryWallet.transferBatch(addrs, amounts);

        assertEq(frakToken.balanceOf(user), 1 ether);
        assertEq(frakToken.balanceOf(address(treasuryWallet)) > 0, true);
    }

    function test_transferBatch_NotMinter_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        (address[] memory addrs, uint256[] memory amounts) = _baseBatchTransferParam(1 ether);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_transferBatch_NoReward_ko() public asDeployer {
        (address[] memory addrs, uint256[] memory amounts) = _baseBatchTransferParam(0);
        vm.expectRevert(NoReward.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_transferBatch_RewardTooLarge_ko() public asDeployer {
        (address[] memory addrs, uint256[] memory amounts) = _baseBatchTransferParam(500_001 ether);
        vm.expectRevert(RewardTooLarge.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_transferBatch_InvalidArray_ko() public asDeployer {
        uint256[] memory amounts = new uint256[](1);
        address[] memory addrs = new address[](2);

        vm.expectRevert(InvalidArray.selector);
        treasuryWallet.transferBatch(addrs, amounts);

        addrs = new address[](0);
        vm.expectRevert(InvalidArray.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_transferBatch_NotEnoughTreasury_ko() public asDeployer {
        uint256 totalToTransfer = 330_000_000 ether;
        uint256 iteration = 500_000 ether;

        do {
            treasuryWallet.transfer(user, iteration);
            totalToTransfer -= iteration;
        } while (totalToTransfer > 0);

        (address[] memory addrs, uint256[] memory amounts) = _baseBatchTransferParam(iteration);
        vm.expectRevert(NotEnoughTreasury.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers                                   */
    /* -------------------------------------------------------------------------- */
    function _baseBatchTransferParam(uint256 amount) private view returns (address[] memory, uint256[] memory) {
        return _baseBatchTransferParam(user, amount);
    }

    function _baseBatchTransferParam(
        address addr,
        uint256 amount
    )
        private
        pure
        returns (address[] memory addresses, uint256[] memory amounts)
    {
        addresses = new address[](1);
        addresses[0] = addr;

        amounts = new uint256[](1);
        amounts[0] = amount;
    }
}
