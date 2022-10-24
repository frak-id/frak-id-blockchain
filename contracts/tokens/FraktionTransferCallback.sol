// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * Interface needing to be implemented for contract who want to receive fraktion transfer callback
 */
/// @custom:security-contact crypto-support@sybel.co
interface FraktionTransferCallback {
    /**
     * Function called when a fraktion is transfered between two person
     */
    function onFraktionsTransfered(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amount
    ) external;
}
