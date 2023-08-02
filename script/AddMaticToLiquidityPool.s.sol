// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoTokenPool} from "singleton-swapper/MonoTokenPool.sol";
import {BaseEncoderLib} from "singleton-swapper/encoder/BaseEncoderLib.sol";
import {MonoOpEncoderLib} from "singleton-swapper/encoder/MonoOpEncoderLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract AddMaticToLiquidityPool is UpgradeScript {
    using SafeTransferLib for address;
    using BaseEncoderLib for bytes;
    using MonoOpEncoderLib for bytes;

    function run() external {
        // Get the current addresses
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        if (addresses.swapPool == address(1)) {
            console.log("Swap pool is not deployed yet");
            return;
        }

        // Get the wmatic address
        address wmatic;
        if (block.chainid == 80001) {
            wmatic = address(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
        } else if (block.chainid == 137) {
            wmatic = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        } else {
            console.log("Unsupported chain id: %s", block.chainid);
            return;
        }

        // Find the mono token pool
        MonoTokenPool pool = MonoTokenPool(payable(addresses.swapPool));

        // Address of the pool owner
        address poolOwner = address(0x7caF754C934710D7C73bc453654552BEcA38223F);

        // Amount of matic to deposit
        uint256 maticAmount = 1e18;

        // Build the command
        (uint256 frkToDeposit, bytes memory addLiquidityCommand) =
            _buildAddLiquidityCommand(addresses.frakToken, wmatic, poolOwner, maticAmount);

        console.log("wMatic address: %s", wmatic);
        console.log("Frk to deposit: %s", frkToDeposit);
        console.log("Matic to deposit: %s", maticAmount);

        // Execute the command
        _executeAddLiquidity(pool, addLiquidityCommand, addresses.frakToken, frkToDeposit, maticAmount);
    }

    /// @dev Build the add liquidity command
    function _buildAddLiquidityCommand(address frkToken, address wmatic, address owner, uint256 maticAmount)
        private
        pure
        returns (uint256 frkToDeposit, bytes memory program)
    {
        // Compute the ration between matic & frak (matic is at 0,68$ and FRK at 0,048)
        frkToDeposit = maticAmount * (uint256(0.68e18) / uint256(0.048e18));

        // Build the programm
        // forgefmt: disable-next-item
        program = BaseEncoderLib
            .init(4)
            .appendAddLiquidity(wmatic, owner, frkToDeposit, maticAmount)
            .appendReceive(wmatic, maticAmount, true)
            .appendPullAll(frkToken)
            .done();
    }

    /// @dev Execute the add liquidity command
    function _executeAddLiquidity(
        MonoTokenPool pool,
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
