// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {FraktionTransferCallback} from "./FraktionTransferCallback.sol";
import {FrakMath} from "../utils/FrakMath.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {InvalidArray} from "../utils/FrakErrors.sol";

/**
 * @author  @KONFeature
 * @title   FraktionTokens
 * @dev  ERC1155 for the Frak Fraktions tokens, used as ownership proof for a content, or investisment proof
 * @custom:security-contact contact@frak.id
 */
contract FraktionTokens is MintingAccessControlUpgradeable, ERC1155Upgradeable {
    using FrakMath for uint256;

    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Error throwned when we don't have enough supply to mint a new fNFT
    error InsuficiantSupply();

    /// @dev Error throwned when we try to update the supply of a non supply aware token
    error SupplyUpdateNotAllowed();

    /// @dev Error emitted when it remain some fraktion supply when wanting to increase it
    error RemainingSupply();

    /// @dev Error emitted when the have more than one fraktions of the given type
    error TooManyFraktion();

    /// @dev 'bytes4(keccak256("InsuficiantSupply()"))'
    uint256 private constant _INSUFICIENT_SUPPLY_SELECTOR = 0xa24b545a;

    /// @dev 'bytes4(keccak256("InvalidArray()"))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256("SupplyUpdateNotAllowed()"))'
    uint256 private constant _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR = 0x48385ebd;

    /// @dev 'bytes4(keccak256("RemainingSupply()"))'
    uint256 private constant _REMAINING_SUPPLY_SELECTOR = 0x0180e6b4;

    /// @dev 'bytes4(keccak256("TooManyFraktion()"))'
    uint256 private constant _TOO_MANY_FRAKTION_SELECTOR = 0xaa37c4ae;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when the supply of a fraktion is updated
    event SuplyUpdated(uint256 indexed id, uint256 supply);

    /// @dev Event emitted when the owner of a content changed
    event ContentOwnerUpdated(uint256 indexed id, address indexed owner);

    /// @dev 'keccak256(bytes("SuplyUpdated(uint256,uint256)"))'
    uint256 private constant _SUPPLY_UPDATED_EVENT_SELECTOR =
        0xb137aebbacc26855c231fff6d377b18aaa6397ab7c49bb7481d78a529017564d;

    /// @dev 'keccak256(bytes("ContentOwnerUpdated(uint256,address)"))'
    uint256 private constant _CONTENT_OWNER_UPDATED_EVENT_SELECTOR =
        0x4d30aa74825efbda2206e0f3ac5b20d3d5806e54280b6684b6f380afcbfc51d2;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The current content token id
    uint256 private _currentContentTokenId;

    /// @dev The current callback
    FraktionTransferCallback private transferCallback;

    /// @dev Id of content to owner of this content
    mapping(uint256 => address) private owners;

    /// @dev Available supply of each tokens (classic, rare, epic and legendary only) by they id
    mapping(uint256 => uint256) private _availableSupplies;

    /// @dev Tell us if that token is supply aware or not
    mapping(uint256 => bool) private _isSupplyAware;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata metadatalUrl) external initializer {
        __ERC1155_init(metadatalUrl);
        __MintingAccessControlUpgradeable_init();
        // Set the initial content id
        _currentContentTokenId = 1;
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Mint a new content, return the id of the built content
     * We will store in memory -from 0x0 to 0x40 ->
     */
    function mintNewContent(address ownerAddress, uint256[] calldata fraktionTypes, uint256[] calldata supplies)
        external
        payable
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
        returns (uint256 id)
    {
        uint256 creatorTokenId;
        assembly {
            // Ensure we got valid data
            if or(iszero(fraktionTypes.length), iszero(eq(fraktionTypes.length, supplies.length))) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }

            // Get the next content id and increment the current content token id
            id := add(sload(_currentContentTokenId.slot), 1)
            sstore(_currentContentTokenId.slot, id)

            // Get the shifted id, to ease the fraktion id creation
            let shiftedId := shl(0x04, id)

            // Iterate over each fraktion type, build their id, and set their supply
            // Get where our offset end
            let offsetEnd := shl(5, fraktionTypes.length)
            // Current iterator offset
            let currentOffset := 0
            // Infinite loop
            for {} 1 {} {
                // Get the current id
                let fraktionType := calldataload(add(fraktionTypes.offset, currentOffset))

                // Ensure the supply update of this token type is allowed
                if or(lt(fraktionType, 3), gt(fraktionType, 6)) {
                    // If token type lower than 3 -> free or owner
                    mstore(0x00, _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR)
                    revert(0x1c, 0x04)
                }

                // Build the fraktion id
                let fraktionId := or(shiftedId, fraktionType)

                // Get the supply
                let supply := calldataload(add(supplies.offset, currentOffset))

                // Get the slot to know if it's supply aware, and store true there
                // Kecak (id, _isSupplyAware.slot)
                mstore(0, fraktionId)
                mstore(0x20, _isSupplyAware.slot)
                sstore(keccak256(0, 0x40), true)

                // Get the supply slot and update it
                // Kecak (id, _availableSupplies.slot)
                // `mstore(0, fraktionId)` -> Not needed since alreaded store on the 0 slot before
                mstore(0x20, _availableSupplies.slot)
                sstore(keccak256(0, 0x40), supply)
                // Emit the supply updated event
                mstore(0, supply)
                log2(0, 0x20, _SUPPLY_UPDATED_EVENT_SELECTOR, fraktionId)

                // Increase the iterator
                currentOffset := add(currentOffset, 0x20)
                // Exit if we reached the end
                if iszero(lt(currentOffset, offsetEnd)) { break }
            }

            // Update creator supply now
            creatorTokenId := or(shiftedId, 1)
            // Get the slot to know if it's supply aware, and store true there
            mstore(0, creatorTokenId)
            mstore(0x20, _isSupplyAware.slot)
            sstore(keccak256(0, 0x40), true)
            // Then store the available supply of 1 (since only one creator nft is possible)
            mstore(0x20, _availableSupplies.slot)
            sstore(keccak256(0, 0x40), 1)
        }

        // Mint the content nft into the content owner wallet directly
        _mint(ownerAddress, creatorTokenId, 1, "");

        // Return the content id
        return id;
    }

    /**
     * @dev Set the supply for the given token id
     */
    function setSupply(uint256 id, uint256 supply) external payable onlyRole(FrakRoles.MINTER) whenNotPaused {
        assembly {
            // Ensure we got valid data
            if iszero(supply) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Ensure the supply update of this token type is allowed
            let fraktionType := and(id, 0xF)
            if or(lt(fraktionType, 3), gt(fraktionType, 6)) {
                // If token type lower than 3 -> free or owner, if greater than 6 -> not a content
                mstore(0x00, _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Kecak (id, _availableSupplies.slot)
            mstore(0, id)
            mstore(0x20, _availableSupplies.slot)
            let supplySlot := keccak256(0, 0x40)
            // Ensure all the supply has been sold
            let currentSupply := sload(supplySlot)
            if currentSupply {
                mstore(0x00, _REMAINING_SUPPLY_SELECTOR)
                revert(0x1c, 0x04)
            }

            // Get the slot to know if it's supply aware, and store true there
            // Kecak (id, _isSupplyAware.slot)
            mstore(0, id)
            mstore(0x20, _isSupplyAware.slot)
            sstore(keccak256(0, 0x40), true)
            // Get the supply slot and update it
            sstore(supplySlot, supply)
            // Emit the supply updated event
            mstore(0, supply)
            log2(0, 0x20, _SUPPLY_UPDATED_EVENT_SELECTOR, id)
        }
    }

    /// @dev Register a new transaction callback
    function registerNewCallback(address callbackAddr) external onlyRole(FrakRoles.ADMIN) whenNotPaused {
        transferCallback = FraktionTransferCallback(callbackAddr);
    }

    /// @dev Mint a new fraction of a nft
    function mint(address to, uint256 id, uint256 amount) external payable onlyRole(FrakRoles.MINTER) whenNotPaused {
        _mint(to, id, amount, "");
    }

    /// @dev Burn a fraction of a nft
    function burn(uint256 id, uint256 amount) external payable whenNotPaused {
        _burn(msg.sender, id, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                        Internal callback function's                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Handle the transfer token (so update the content investor, change the owner of some content etc)
     */
    function _beforeTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal override {
        assembly {
            // Base offset to access array element's
            let currOffset := 0x20
            let offsetEnd := add(currOffset, shl(5, mload(ids)))

            // Infinite loop
            for {} 1 {} {
                // Get the id and amount
                let id := mload(add(ids, currOffset))
                let amount := mload(add(amounts, currOffset))

                // Get the slot to know if it's supply aware
                // Kecak (id, _isSupplyAware.slot)
                mstore(0, id)
                mstore(0x20, _isSupplyAware.slot)

                // Supply aware code block
                if sload(keccak256(0, 0x40)) {
                    // Get the supply slot
                    // Kecak (id, _availableSupplies.slot)
                    // mstore(0, id) -> Don't needed since we already stored the id before in this mem space
                    mstore(0x20, _availableSupplies.slot)
                    let availableSupplySlot := keccak256(0, 0x40)
                    let availableSupply := sload(availableSupplySlot)
                    // Ensure we have enough supply
                    if and(iszero(from), gt(amount, availableSupply)) {
                        mstore(0x00, _INSUFICIENT_SUPPLY_SELECTOR)
                        revert(0x1c, 0x04)
                    }
                    // Update the supply
                    if iszero(from) { availableSupply := sub(availableSupply, amount) }
                    if iszero(to) { availableSupply := add(availableSupply, amount) }
                    sstore(availableSupplySlot, availableSupply)
                }

                // Check if the recipient don't already have one fraktion of this type
                if to {
                    // If the amount is greater than 1, abort
                    if gt(amount, 1) {
                        mstore(0, _TOO_MANY_FRAKTION_SELECTOR)
                        revert(0x1c, 0x04)
                    }
                    // Get the slot for the current id
                    mstore(0, id)
                    mstore(0x20, 0xcb) // `_balances.slot` on the OZ contract
                    let idSlot := keccak256(0, 0x40)
                    // Slot for the balance of the given account
                    mstore(0, to)
                    mstore(0x20, idSlot)
                    let balanceSlot := keccak256(0, 0x40)
                    // If the recipient already have a balance for this id, exit directly
                    if sload(balanceSlot) {
                        mstore(0, _TOO_MANY_FRAKTION_SELECTOR)
                        revert(0x1c, 0x04)
                    }
                }

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }
        }
    }

    /**
     * @dev Handle the transfer token (so update the content investor, change the owner of some content etc)
     */
    function _afterTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal override whenNotPaused {
        assembly {
            // Base offset to access array element's
            let currOffset := 0x20
            let offsetEnd := add(currOffset, shl(5, mload(ids)))

            // Check if we got at least one fraktion needing callback (one that is higher than creator or free)
            let hasOneFraktionForCallback := false

            // Infinite loop
            for {} 1 {} {
                // Get the id and amount
                let id := mload(add(ids, currOffset))

                // Content owner migration code block
                if eq(and(id, 0xF), 1) {
                    let contentId := shr(0x04, id)
                    // Get the owner slot
                    // Kecak (contentId, owners.slot)
                    mstore(0, contentId)
                    mstore(0x20, owners.slot)
                    // Update the owner
                    sstore(keccak256(0, 0x40), to)
                    // Log the event
                    log3(0, 0, _CONTENT_OWNER_UPDATED_EVENT_SELECTOR, contentId, to)
                }

                // Check if we need to include this in our filtered ids array
                hasOneFraktionForCallback := or(hasOneFraktionForCallback, gt(and(id, 0xF), 2))

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }

            // If no fraktion needing callback, exit directly
            if iszero(hasOneFraktionForCallback) { return(0, 0x20) }
            // If empty callback address, exit directly
            if iszero(sload(transferCallback.slot)) { return(0, 0x20) }
        }

        // Call our callback
        transferCallback.onFraktionsTransferred(from, to, ids, amounts);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Public view function's                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Batch balance of for single address
     */
    function balanceOfIdsBatch(address account, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory batchBalances)
    {
        assembly {
            // Get the free mem pointer for our batch balances
            batchBalances := mload(0x40)
            // Store the size of our array
            mstore(batchBalances, ids.length)
            // Get where our array ends
            let end := add(ids.offset, shl(5, ids.length))
            // Current iterator offset
            let i := ids.offset
            // Current balance array offset
            let balanceOffset := add(batchBalances, 0x20)
            // Infinite loop
            for {} 1 {} {
                // Get the slot for the current id
                mstore(0, calldataload(i))
                mstore(0x20, 0xcb) // `_balances.slot` on the OZ contract
                let idSlot := keccak256(0, 0x40)
                // Slot for the balance of the given account
                mstore(0, account)
                mstore(0x20, idSlot)
                let balanceSlot := keccak256(0, 0x40)
                // Set the balance at the right index
                mstore(balanceOffset, sload(balanceSlot))
                // Increase the iterator
                i := add(i, 0x20)
                balanceOffset := add(balanceOffset, 0x20)
                // Exit if we reached the end
                if iszero(lt(i, end)) { break }
            }
            // Set the new free mem pointer
            mstore(0x40, balanceOffset)
        }
    }

    /// @dev Find the owner of the given 'contentId'
    function ownerOf(uint256 contentId) external view returns (address) {
        return owners[contentId];
    }

    /// @dev Find the current supply of the given 'tokenId'
    function supplyOf(uint256 tokenId) external view returns (uint256) {
        return _availableSupplies[tokenId];
    }
}
