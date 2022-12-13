// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

/**
 * Interface needing to be implemented for contract who want to receive fraktion transfer callback
 */
/// @custom:security-contact contact@frak.id
interface FraktionTransferCallback {
    /**
     * Function called when a fraktion is transfered between two person
     */
    function onFraktionsTransferred(address from, address to, uint256[] memory ids, uint256[] memory amount) external;
}
