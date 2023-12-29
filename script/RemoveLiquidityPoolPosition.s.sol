// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { MonoPool } from "swap-pool/MonoPool.sol";
import { Token } from "swap-pool/libs/TokenLib.sol";
import { EncoderLib } from "swap-pool/encoder/EncoderLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

contract RemoveLiquidityPoolPosition is UpgradeScript {
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
        address poolOwner = _deployerAddress();

        // Get the position
        uint256 position = pool.getPosition(poolOwner);
        (Token token0, Token token1) = pool.getTokens();
        console.log("Pool position : %s", position);
        console.log("Pool token0 : %s", Token.unwrap(token0));
        console.log("Pool token1 : %s", Token.unwrap(token1));

        // Build the command
        bytes memory program = _builRemoveLiquidityCommand(poolOwner, position);

        // Execute the command
        _executeRemoveLiquidity(pool, program);
    }

    /// @dev Build the add liquidity command
    function _builRemoveLiquidityCommand(address owner, uint256 position) private pure returns (bytes memory program) {
        // Build the programm
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendRemoveLiquidity(position)
            .appendSendAll(true, owner)
            .appendSendAll(false, owner)
            .done();
    }

    /// @dev Build the add liquidity command
    function _builRemoveLiquidityAndClaimFeesCommand(
        address owner,
        uint256 position
    )
        private
        pure
        returns (bytes memory program)
    {
        // Build the programm
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendClaimFees()
            .appendRemoveLiquidity(position)
            .appendSendAll(true, owner)
            .appendSendAll(false, owner)
            .done();
    }

    /// @dev Transfer the fees ownership
    function _transferFeesOwnership(MonoPool pool, address newOwner) private deployerBroadcast {
        pool.updateFeeReceiver(newOwner, 100);
    }

    /// @dev Execute the remove liquidity command
    function _executeRemoveLiquidity(MonoPool pool, bytes memory program) private deployerBroadcast {
        // Execute the command
        pool.execute(program);
    }
}
