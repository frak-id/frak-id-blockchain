// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { StdUtils } from "@forge-std/StdUtils.sol";
import { FrakToken } from "@frak/tokens/FrakToken.sol";
import { ArrayLib } from "@frak/libs/ArrayLib.sol";
import { FrakRoles } from "@frak/roles/FrakRoles.sol";
import { FrakTreasuryWallet, NotEnoughTreasury } from "@frak/wallets/FrakTreasuryWallet.sol";
import { FrkTokenTestHelper } from "../FrkTokenTestHelper.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "@frak/utils/FrakErrors.sol";

/// Testing the frak l2 token
contract FrakTreasuryWalletTest is FrkTokenTestHelper, StdUtils {
    using ArrayLib for address;
    using ArrayLib for uint256;

    address treasuryWalletAddr;
    FrakTreasuryWallet treasuryWallet;

    function setUp() public {
        _setupFrkToken();

        // Deploy our multi vesting wallets
        bytes memory initData = abi.encodeCall(FrakTreasuryWallet.initialize, (address(frakToken)));
        treasuryWalletAddr = deployContract(address(new FrakTreasuryWallet()), initData);
        treasuryWallet = FrakTreasuryWallet(treasuryWalletAddr);

        // Grant the minter role to our treasury wallets
        prankDeployer();
        frakToken.grantRole(FrakRoles.MINTER, treasuryWalletAddr);
    }

    /*
     * ===== TEST : initialize(address tokenAddr) =====
     */
    function test_fail_initialize_CantInitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        treasuryWallet.initialize(address(0));
    }

    /*
     * ===== TEST : transfer(address target, uint256 amount) =====
     */
    function test_transfer() public {
        prankDeployer();
        treasuryWallet.transfer(address(1), 1 ether);

        assertEq(frakToken.balanceOf(address(1)), 1 ether);
        assertEq(frakToken.balanceOf(treasuryWalletAddr) > 0, true);
    }

    function testFuzz_transfer(address target, uint96 amount) public {
        vm.assume(target != address(0));
        amount = uint96(bound(amount, 1, 500_000 ether));

        // Get the previous balance
        uint256 prevBalance = frakToken.balanceOf(target);

        prankDeployer();
        treasuryWallet.transfer(target, uint256(amount));

        // Get the balance diff
        uint256 newBalance = frakToken.balanceOf(target);
        uint256 balanceDiff = newBalance - prevBalance;

        assertEq(balanceDiff, uint256(amount));
    }

    function test_fail_transfer_NotMinter() public {
        vm.expectRevert(NotAuthorized.selector);
        treasuryWallet.transfer(address(1), 1 ether);
    }

    function test_fail_transfer_InvalidAddress() public prankExecAsDeployer {
        vm.expectRevert(InvalidAddress.selector);
        treasuryWallet.transfer(address(0), 1 ether);
    }

    function test_fail_transfer_NoReward() public prankExecAsDeployer {
        vm.expectRevert(NoReward.selector);
        treasuryWallet.transfer(address(1), 0);
    }

    function test_fail_transfer_RewardTooLarge() public prankExecAsDeployer {
        vm.expectRevert(RewardTooLarge.selector);
        treasuryWallet.transfer(address(1), 500_001 ether);
    }

    function test_fail_transfer_NotEnoughTreasury() public prankExecAsDeployer {
        uint256 totalToTransfer = 330_000_000 ether;
        uint256 iteration = 500_000 ether;

        do {
            treasuryWallet.transfer(address(1), iteration);
            totalToTransfer -= iteration;
        } while (totalToTransfer > 0);

        vm.expectRevert(NotEnoughTreasury.selector);
        treasuryWallet.transfer(address(1), iteration);
    }

    /*
     * ===== TEST : transferBatch(address[] calldata targets, uint256[] calldata amounts) =====
        uint256[] memory listenCounts = new uint256[](1);
     */
    function test_transferBatch() public {
        prankDeployer();
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(1 ether);
        treasuryWallet.transferBatch(addrs, amounts);

        assertEq(frakToken.balanceOf(address(1)), 1 ether);
        assertEq(frakToken.balanceOf(treasuryWalletAddr) > 0, true);
    }

    function testFuzz_transferBatch(address target, uint96 amount) public {
        vm.assume(target != address(0));
        amount = uint96(bound(amount, 1, 500_000 ether));

        // Get the previous balance
        uint256 prevBalance = frakToken.balanceOf(target);

        prankDeployer();
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(target, uint256(amount));
        treasuryWallet.transferBatch(addrs, amounts);

        // Get the balance diff
        uint256 newBalance = frakToken.balanceOf(target);
        uint256 balanceDiff = newBalance - prevBalance;

        assertEq(balanceDiff, uint256(amount));
    }

    function test_fail_transferBatch_NotMinter() public {
        vm.expectRevert(NotAuthorized.selector);
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(1 ether);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_NoReward() public prankExecAsDeployer {
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(0);
        vm.expectRevert(NoReward.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_RewardTooLarge() public prankExecAsDeployer {
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(500_001 ether);
        vm.expectRevert(RewardTooLarge.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_InvalidArray() public prankExecAsDeployer {
        uint256[] memory amounts = uint256(1 ether).asSingletonArray();
        address[] memory addrs = new address[](2);
        vm.expectRevert(InvalidArray.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_InvalidArray_Empty() public prankExecAsDeployer {
        uint256[] memory amounts = uint256(1 ether).asSingletonArray();
        address[] memory addrs = new address[](0);
        vm.expectRevert(InvalidArray.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_NotEnoughTreasury() public prankExecAsDeployer {
        uint256 totalToTransfer = 330_000_000 ether;
        uint256 iteration = 500_000 ether;

        do {
            treasuryWallet.transfer(address(1), iteration);
            totalToTransfer -= iteration;
        } while (totalToTransfer > 0);

        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(iteration);
        vm.expectRevert(NotEnoughTreasury.selector);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    /*
     * ===== TEST : multicall(bytes[] calldata data) =====
     */
    function test_multicall() public prankExecAsDeployer {
        // Build our calldata
        bytes[] memory callingData = new bytes[](2);
        callingData[0] = abi.encodeWithSelector(treasuryWallet.transfer.selector, address(1), 1);
        callingData[1] = abi.encodeWithSelector(treasuryWallet.transfer.selector, address(1), 2);

        treasuryWallet.multicall(callingData);
    }

    function testFuzz_multicall(uint256 amount, address target1, address target2) public prankExecAsDeployer {
        vm.assume(target1 != address(0) && target2 != address(0));
        amount = bound(amount, 1, 500_000 ether);

        // Build our calldata
        bytes[] memory callingData = new bytes[](2);
        callingData[0] = abi.encodeWithSelector(treasuryWallet.transfer.selector, target1, amount);
        callingData[1] = abi.encodeWithSelector(treasuryWallet.transfer.selector, target2, amount);

        treasuryWallet.multicall(callingData);
    }

    function test_fail_multicall_NotAuthorized() public {
        // Build our calldata
        bytes[] memory callingData = new bytes[](2);
        callingData[0] = abi.encodeWithSelector(treasuryWallet.transfer.selector, address(1), 1);
        callingData[1] = abi.encodeWithSelector(treasuryWallet.transfer.selector, address(1), 2);

        vm.expectRevert(NotAuthorized.selector);
        treasuryWallet.multicall(callingData);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    function baseBatchParam(uint256 amount) private pure returns (address[] memory, uint256[] memory) {
        return baseBatchParam(address(1), amount);
    }

    function baseBatchParam(address addr, uint256 amount) private pure returns (address[] memory, uint256[] memory) {
        return (addr.asSingletonArray(), uint256(amount).asSingletonArray());
    }
}
