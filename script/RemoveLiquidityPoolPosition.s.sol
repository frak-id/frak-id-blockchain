// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoPool} from "swap-pool/MonoPool.sol";
import {EncoderLib} from "swap-pool/encoder/EncoderLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

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
        address poolOwner = address(0x7caF754C934710D7C73bc453654552BEcA38223F);

        // Get the position
        uint256 position = pool.getPosition(poolOwner);
        (address token0, address token1) = pool.getTokens();
        console.log("Pool position : %s", position);
        console.log("Pool token0 : %s", token0);
        console.log("Pool token1 : %s", token1);

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
            .appendSendAll(true, owner, false)
            .appendSendAll(false, owner, true)
            .done();
    }

    /// @dev Execute the remove liquidity command
    function _executeRemoveLiquidity(MonoPool pool, bytes memory program) private deployerBroadcast {
        // Execute the command
        pool.execute(program);
    }
}
