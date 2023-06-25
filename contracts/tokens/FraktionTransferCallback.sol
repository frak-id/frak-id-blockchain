// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

/**
 * @author  @KONFeature
 * @title   FraktionTransferCallback
 * @dev  Interface for contract who want to listen of the fraktion transfer (ERC1155 tokens transfer)
 * @custom:security-contact contact@frak.id
 */
interface FraktionTransferCallback {
    /**
     * @dev Function called when a fraktion is transfered between two person
     */
    function onFraktionsTransferred(address from, address to, uint256[] memory ids, uint256[] memory amount)
        external
        payable;
}
