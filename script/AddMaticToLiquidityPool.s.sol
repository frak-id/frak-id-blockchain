// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { MonoPool } from "swap-pool/MonoPool.sol";
import { EncoderLib } from "swap-pool/encoder/EncoderLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

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

        // Amount of matic to deposit
        uint256 frkToDeposit = 103.96 ether;
        uint256 maticAmount = 9.09 ether;

        // Build the command
        bytes memory addLiquidityCommand = _buildAddLiquidityCommand(frkToDeposit, maticAmount);

        console.log("Will deposit Frk  : %s", frkToDeposit);
        console.log("Will deposit Matic: %s", maticAmount);

        // Execute the command
        _executeAddLiquidity(pool, addLiquidityCommand, addresses.frakToken, frkToDeposit, maticAmount);
    }

    /// @dev Build the add liquidity command
    function _buildAddLiquidityCommand(
        uint256 frkToDeposit,
        uint256 maticAmount
    )
        private
        pure
        returns (bytes memory program)
    {
        // Build the programm
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendAddLiquidity(frkToDeposit, maticAmount)
            .appendReceive(false, maticAmount)
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
    )
        private
        deployerBroadcast
    {
        // Approve the pool to spend the frk
        frkToken.safeApprove(address(pool), frkAmount);

        // Execute the command
        pool.execute{ value: maticAmount }(program);
    }
}
