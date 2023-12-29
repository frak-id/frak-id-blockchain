// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { FraktionId } from "../libs/FraktionId.sol";

/// @author @KONFeature
/// @title FraktionTransferCallback
/// @notice Interface for contract who want to listen of the fraktion transfer (ERC1155 tokens transfer)
/// @custom:security-contact contact@frak.id
interface FraktionTransferCallback {
    /**
     * @dev Function called when a fraktion is transfered between two person
     */
    function onFraktionsTransferred(
        address from,
        address to,
        FraktionId[] memory ids,
        uint256[] memory amount
    )
        external
        payable;
}
