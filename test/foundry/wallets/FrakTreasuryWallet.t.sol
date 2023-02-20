// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {FrakToken} from "@frak/tokens/FrakTokenL2.sol";
import {FrakMath} from "@frak/utils/FrakMath.sol";
import {FrakRoles} from "@frak/utils/FrakRoles.sol";
import {FrakTreasuryWallet, NotEnoughTreasury} from "@frak/wallets/FrakTreasuryWallet.sol";
import {FrkTokenTestHelper} from "../FrkTokenTestHelper.sol";
import {NotAuthorized, InvalidAddress, NoReward, ContractPaused, RewardTooLarge, InvalidArray} from "@frak/utils/FrakErrors.sol";

/// Testing the frak l2 token
contract FrakTreasuryWalletTest is FrkTokenTestHelper {
    using FrakMath for address;
    using FrakMath for uint256;

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

    function testFuzz_transfer(address target, uint256 amount) public {
        vm.assume(amount > 0 && amount < 500_000 ether && target != address(0));

        prankDeployer();
        treasuryWallet.transfer(target, amount);

        assertEq(frakToken.balanceOf(target), amount);
    }

    function test_fail_transfer_NotMinter() public {
        vm.expectRevert(NotAuthorized.selector);
        treasuryWallet.transfer(address(1), 1 ether);
    }

    function test_fail_transfer_ContractPaused() public prankExecAsDeployer {
        treasuryWallet.pause();

        vm.expectRevert(ContractPaused.selector);
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

    function testFuzz_transferBatch(address target, uint256 amount) public {
        vm.assume(amount > 0 && amount < 500_000 ether && target != address(0));

        prankDeployer();
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(target, amount);
        treasuryWallet.transferBatch(addrs, amounts);

        assertEq(frakToken.balanceOf(target), amount);
    }

    function test_fail_transferBatch_NotMinter() public {
        vm.expectRevert(NotAuthorized.selector);
        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(1 ether);
        treasuryWallet.transferBatch(addrs, amounts);
    }

    function test_fail_transferBatch_ContractPaused() public prankExecAsDeployer {
        treasuryWallet.pause();

        (address[] memory addrs, uint256[] memory amounts) = baseBatchParam(1 ether);
        vm.expectRevert(ContractPaused.selector);
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

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    function baseBatchParam(uint256 amount) private view returns (address[] memory, uint256[] memory) {
        return baseBatchParam(address(1), amount);
    }

    function baseBatchParam(address addr, uint256 amount) private view returns (address[] memory, uint256[] memory) {
        return (addr.asSingletonArray(), uint256(amount).asSingletonArray());
    }
}
