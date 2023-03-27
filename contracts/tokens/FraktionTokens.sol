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

    /// @dev 'bytes4(keccak256(bytes("InsuficiantSupply()")))'
    uint256 private constant _INSUFICIENT_SUPPLY_SELECTOR = 0xa24b545a;

    /// @dev 'bytes4(keccak256(bytes("InvalidArray()")))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256(bytes("SupplyUpdateNotAllowed()")))'
    uint256 private constant _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR = 0x48385ebd;

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
     */
    function mintNewContent(address ownerAddress)
        external
        payable
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
        returns (uint256 id)
    {
        // Get the next content id and increment the current content token id
        assembly {
            id := add(sload(_currentContentTokenId.slot), 1)
            sstore(_currentContentTokenId.slot, id)
        }

        // Mint the content nft into the content owner wallet directly
        uint256 nftId = id.buildNftId();
        _isSupplyAware[nftId] = true;
        _availableSupplies[nftId] = 1;
        _mint(ownerAddress, nftId, 1, new bytes(0x0));

        // Return the content id
        return id;
    }

    /**
     * @dev Set the supply for each token ids
     */
    function setSupplyBatch(uint256[] calldata ids, uint256[] calldata supplies)
        external
        payable
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
        assembly {
            // Ensure we got valid data
            if or(iszero(ids.length), iszero(eq(ids.length, supplies.length))) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }

            // Get where our array ends
            let offsetEnd := shl(5, ids.length)
            // Current iterator offset
            let currentOffset := 0
            // Infinite loop
            for {} 1 {} {
                // Get the current id and supply
                let id := calldataload(add(ids.offset, currentOffset))
                let supply := calldataload(add(supplies.offset, currentOffset))

                // Ensure the supply update of this token type is allowed
                let tokenType := and(id, 0xF)
                if lt(tokenType, 3) {
                    // If token type lower than 3 -> free or owner
                    mstore(0x00, _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR)
                    revert(0x1c, 0x04)
                }

                // Get the slot to know if it's supply aware, and store true there
                // Kecak (id, _isSupplyAware.slot)
                mstore(0, id)
                mstore(0x20, _isSupplyAware.slot)
                sstore(keccak256(0, 0x40), true)
                // Get the supply slot and update it
                // Kecak (id, _availableSupplies.slot)
                mstore(0, id)
                mstore(0x20, _availableSupplies.slot)
                sstore(keccak256(0, 0x40), supply)
                // Emit the supply updated event
                mstore(0, supply)
                log2(0, 0x20, _SUPPLY_UPDATED_EVENT_SELECTOR, id)

                // Increase the iterator
                currentOffset := add(currentOffset, 0x20)
                // Exit if we reached the end
                if iszero(lt(currentOffset, offsetEnd)) { break }
            }
        }
    }

    /// @dev Register a new transaction callback
    function registerNewCallback(address callbackAddr) external onlyRole(FrakRoles.ADMIN) whenNotPaused {
        transferCallback = FraktionTransferCallback(callbackAddr);
    }

    /// @dev Mint a new fraction of a nft
    function mint(address to, uint256 id, uint256 amount) external payable onlyRole(FrakRoles.MINTER) whenNotPaused {
        _mint(to, id, amount, new bytes(0x0));
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
    function _afterTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal override whenNotPaused {
        assembly {
            // Get the length
            let length := mload(ids)

            // Base offset to access array element's
            let currOffset := 0x20
            let offsetEnd := add(currOffset, shl(5, length))

            // Infinite loop
            for {} 1 {} {
                let id := mload(add(ids, currOffset))

                // Get the slot to know if it's supply aware
                // Kecak (id, _isSupplyAware.slot)
                mstore(0, id)
                mstore(0x20, _isSupplyAware.slot)
                let isSupplyAware := sload(keccak256(0, 0x40))

                // Supply aware code block
                if isSupplyAware {
                    // Get the amount
                    let amount := mload(add(amounts, currOffset))
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

                // Content owner migration code block
                let isOwnerNft := eq(and(id, 0xF), 1)
                if isOwnerNft {
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

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }
        }

        // Call our callback
        // TODO : Assembly pre filtering of the array, only keeping element with type > 2
        if (address(transferCallback) != address(0)) {
            transferCallback.onFraktionsTransferred(from, to, ids, amounts);
        }
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
