// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { UpgradeScript } from "./utils/UpgradeScript.s.sol";
import { MonoPool } from "swap-pool/MonoPool.sol";
import { EncoderLib } from "swap-pool/encoder/EncoderLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FrakToken } from "contracts/tokens/FrakTokenL2.sol";

contract PerformMaticFrkSwap is UpgradeScript {
    using SafeTransferLib for address;
    using EncoderLib for bytes;

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

        // Find the mono token pool
        MonoPool pool = MonoPool(payable(addresses.swapPool));

        // Get the pool reserves and log it
        console.log("=== Pre swap ===");
        _postPoolReserveLog(pool);

        // Address of the pool owner
        address swapUser = _deployerAddress();

        // Build the swap matic command
        console.log("=== Matic->frk swap ===");
        uint256 maticAmount = 0.05 ether;
        bytes memory swapMaticCommand = _buildSwapMaticToFrkCommand(maticAmount, swapUser);

        console.log("Matic to swap: %s", maticAmount);
        console.log("Swap user: %s", swapUser);

        // Execute the command
        _executeMaticSwap(pool, swapMaticCommand, maticAmount);

        _postPoolReserveLog(pool);

        // Build the swap frk command
        console.log("=== Frk->matic swap ===");
        uint256 frkAmount = 5 ether;
        bytes memory swapFrkCommand =
            _buildSwapFrkToMaticCommand(FrakToken(addresses.frakToken), address(pool), frkAmount, _deployerPrivateKey());

        console.log("Frak to swap: %s", frkAmount);
        console.log("Swap user: %s", vm.addr(_deployerPrivateKey()));

        // Execute the command
        _executeFrkSwap(pool, swapFrkCommand);

        console.log("=== Post swap ===");
        _postPoolReserveLog(pool);
    }

    /// @dev Build the matic to frk swap command
    function _buildSwapMaticToFrkCommand(
        uint256 maticAmount,
        address user
    )
        private
        pure
        returns (bytes memory program)
    {
        // Build the program
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendSwap(false, maticAmount)
            .appendReceive(false, maticAmount)
            .appendSendAll(true, user)
            .done();
    }

    /// @dev Build the frk to matic swap command
    function _buildSwapFrkToMaticCommand(
        FrakToken frkToken,
        address pool,
        uint256 frkAmount,
        uint256 privateKey
    )
        private
        view
        returns (bytes memory program)
    {
        // Generate the signature
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _generatePermitSignature(SignatureParams(frkToken, pool, frkAmount, privateKey));

        AppendPermitSignature memory permitParams =
            AppendPermitSignature(vm.addr(privateKey), frkAmount, deadline, v, r, s);

        // Build the program
        // forgefmt: disable-next-item
        program = EncoderLib
            .init()
            .appendSwap(true, frkAmount);
        return _appendPermitSignature(program, permitParams).done();
    }

    struct AppendPermitSignature {
        address user;
        uint256 frkAmount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function _appendPermitSignature(
        bytes memory program,
        AppendPermitSignature memory params
    )
        internal
        pure
        returns (bytes memory)
    {
        // forgefmt: disable-next-item
        return program
        .appendPermitViaSig(true, params.frkAmount, params.deadline, params.v, params.r, params.s)
        .appendReceiveAll(true)
        .appendSendAll(false, params.user);
    }

    struct SignatureParams {
        FrakToken frkToken;
        address pool;
        uint256 frkAmount;
        uint256 privateKey;
    }

    /// @dev Generate the permit signature
    function _generatePermitSignature(SignatureParams memory params)
        internal
        view
        returns (uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    {
        // Get the param for the signature
        address user = vm.addr(params.privateKey);
        deadline = block.timestamp + 100;

        // Generate the signature
        (v, r, s) = vm.sign(
            params.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    params.frkToken.getDomainSeperator(),
                    keccak256(
                        abi.encode(
                            _PERMIT_TYPEHASH,
                            user,
                            params.pool,
                            params.frkAmount,
                            params.frkToken.getNonce(user),
                            deadline
                        )
                    )
                )
            )
        );
    }

    /// @dev Execute the add liquidity command
    function _executeMaticSwap(MonoPool pool, bytes memory program, uint256 maticAmount) private deployerBroadcast {
        // Execute the command
        pool.execute{ value: maticAmount }(program);
    }

    /// @dev Execute the add liquidity command
    function _executeFrkSwap(MonoPool pool, bytes memory program) private deployerBroadcast {
        // Execute the command
        pool.execute(program);
    }

    /// @dev post the liquidity pool reserves
    function _postPoolReserveLog(MonoPool pool) internal view {
        (uint256 totalLiquidity, uint256 reserves0, uint256 reserves1) = pool.getPoolState();
        console.log("- Pool");
        console.log(" - reserves0: %s", reserves0);
        console.log(" - reserves1: %s", reserves1);
        console.log(" - totalLiquidity: %s", totalLiquidity);
    }
}
