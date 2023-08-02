// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {UpgradeScript} from "./utils/UpgradeScript.s.sol";
import {MonoTokenPool} from "singleton-swapper/MonoTokenPool.sol";
import {BaseEncoderLib} from "singleton-swapper/encoder/BaseEncoderLib.sol";
import {MonoOpEncoderLib} from "singleton-swapper/encoder/MonoOpEncoderLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FrakToken} from "contracts/tokens/FrakTokenL2.sol";

contract PerformMaticFrkSwap is UpgradeScript {
    using SafeTransferLib for address;
    using BaseEncoderLib for bytes;
    using MonoOpEncoderLib for bytes;

    /// @dev The permit typehash
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

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

        // Get the pool reserves and log it
        console.log("=== Pre swap ===");
        _postPoolReserveLog(pool, wmatic);

        // Address of the pool owner
        address swapUser = address(0x7caF754C934710D7C73bc453654552BEcA38223F);

        // Build the swap matic command
        console.log("=== Matic->frk swap ===");
        uint256 maticAmount = 0.5e18;
        bytes memory swapMaticCommand = _buildSwapMaticToFrkCommand(addresses.frakToken, wmatic, maticAmount, swapUser);

        console.log("wMatic address: %s", wmatic);
        console.log("Matic to swap: %s", maticAmount);
        console.log("Swap user: %s", swapUser);

        // Execute the command
        _executeMaticSwap(pool, swapMaticCommand, maticAmount);

        _postPoolReserveLog(pool, wmatic);

        // Build the swap frk command
        console.log("=== Frk->matic swap ===");
        uint256 frkAmount = 3e18;
        bytes memory swapFrkCommand = _buildSwapFrkToMaticCommand(
            FrakToken(addresses.frakToken), address(pool), wmatic, frkAmount, _deployerPrivateKey()
        );

        console.log("wMatic address: %s", wmatic);
        console.log("Frak to swap: %s", frkAmount);
        console.log("Swap user: %s", vm.addr(_deployerPrivateKey()));

        // Execute the command
        _executeFrkSwap(pool, swapFrkCommand);

        console.log("=== Post swap ===");
        _postPoolReserveLog(pool, wmatic);
    }

    /// @dev Build the matic to frk swap command
    function _buildSwapMaticToFrkCommand(address frkToken, address wmatic, uint256 maticAmount, address user)
        private
        pure
        returns (bytes memory program)
    {
        // Build the program
        // forgefmt: disable-next-item
        program = BaseEncoderLib.init(4)
            .appendSwap(wmatic, false, maticAmount)
            .appendReceive(wmatic, maticAmount, true)
            .appendSendAll(frkToken, user)
            .done();
    }

    /// @dev Build the frk to matic swap command
    function _buildSwapFrkToMaticCommand(
        FrakToken frkToken,
        address pool,
        address wmatic,
        uint256 frkAmount,
        uint256 privateKey
    ) private view returns (bytes memory program) {
        // Get the param for the signature
        address user = vm.addr(privateKey);
        uint256 deadline = block.timestamp + 100;
        uint256 nonce = frkToken.getNonce(user);

        // Generate the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    frkToken.getDomainSeperator(),
                    keccak256(abi.encode(_PERMIT_TYPEHASH, user, pool, frkAmount, nonce, deadline))
                )
            )
        );

        // Build the program
        // forgefmt: disable-next-item
        program = BaseEncoderLib.init(4)
            .appendSwap(wmatic, true, frkAmount)
            .appendPermitViaSig(address(frkToken), frkAmount, deadline, v, r, s)
            .appendPullAll(address(frkToken))
            .appendSendAllAndUnwrap(wmatic, user)
            .done();
    }

    /// @dev Execute the add liquidity command
    function _executeMaticSwap(MonoTokenPool pool, bytes memory program, uint256 maticAmount)
        private
        deployerBroadcast
    {
        // Execute the command
        pool.execute{value: maticAmount}(program);
    }

    /// @dev Execute the add liquidity command
    function _executeFrkSwap(MonoTokenPool pool, bytes memory program) private deployerBroadcast {
        // Execute the command
        pool.execute(program);
    }

    /// @dev post the liquidity pool reserves
    function _postPoolReserveLog(MonoTokenPool pool, address wmatic) internal view {
        (uint128 reserves0, uint128 reserves1, uint256 totalLiquidity) = pool.getPool(wmatic);
        console.log("- Pool");
        console.log(" - reserves0: %s", reserves0);
        console.log(" - reserves1: %s", reserves1);
        console.log(" - totalLiquidity: %s", totalLiquidity);
    }
}
