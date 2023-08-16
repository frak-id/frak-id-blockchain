// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoPool} from "swap-pool/MonoPool.sol";
import {EncoderLib} from "swap-pool/encoder/EncoderLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract AddMaticToLiquidityPool is UpgradeScript {
    using SafeTransferLib for address;
    using EncoderLib for bytes;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        if (addresses.swapPool == address(1)) {
            console.log("Swap pool is not deployed yet");
            return;
        }

        // Find the mono token pool
        MonoPool pool = MonoPool(payable(addresses.swapPool));

        // Address of the pool owner
        address poolOwner = address(0x7caF754C934710D7C73bc453654552BEcA38223F);

        // Amount of matic to deposit
        uint256 maticAmount = 5 ether;

        // Build the command
        (uint256 frkToDeposit, bytes memory addLiquidityCommand) = _buildAddLiquidityCommand(poolOwner, maticAmount);

        console.log("Will deposit Frk  : %s", frkToDeposit);
        console.log("Will deposit Matic: %s", maticAmount);

        // Execute the command
        _executeAddLiquidity(pool, addLiquidityCommand, addresses.frakToken, frkToDeposit, maticAmount);
    }

    /// @dev Build the add liquidity command
    function _buildAddLiquidityCommand(address owner, uint256 maticAmount)
        private
        pure
        returns (uint256 frkToDeposit, bytes memory program)
    {
        // Compute the ration between matic & frak (ration at 13.72)
        frkToDeposit = (maticAmount * 13_720) / 1000;

        // Build the programm
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendAddLiquidity(owner, frkToDeposit, maticAmount)
            .appendReceive(false, maticAmount, true)
            .appendReceiveAll(true)
            .done();
    }

    /// @dev Execute the add liquidity command
    function _executeAddLiquidity(
        MonoPool pool,
        bytes memory program,
        address frkToken,
        uint256 frkAmount,
        uint256 maticAmount
    ) private deployerBroadcast {
        // Approve the pool to spend the frk
        frkToken.safeApprove(address(pool), frkAmount);

        // Execute the command
        pool.execute{value: maticAmount}(program);
    }
}
