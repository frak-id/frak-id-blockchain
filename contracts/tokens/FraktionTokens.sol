// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {FraktionTransferCallback} from "./FraktionTransferCallback.sol";
import {FrakMath} from "../utils/FrakMath.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {InvalidArray} from "../utils/FrakErrors.sol";

/// @dev Error throwned when we don't have enough supply to mint a new fNFT
error InsuficiantSupply();

/// @dev Error throwned when we try to update the supply of a non supply aware token
error SupplyUpdateNotAllowed();

/**
 * @author  @KONFeature
 * @title   FraktionTokens
 * @dev  ERC1155 for the Frak Fraktions tokens, used as ownership proof for a content, or investisment proof
 * @custom:security-contact contact@frak.id
 */
contract FraktionTokens is MintingAccessControlUpgradeable, ERC1155Upgradeable {
    using FrakMath for uint256;

    /// @dev 'bytes4(keccak256(bytes("InsuficiantSupply()")))'
    uint256 private constant _INSUFICIENT_SUPPLY_SELECTOR = 0xa24b545a;

    /// @dev 'bytes4(keccak256(bytes("InvalidArray()")))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256(bytes("SupplyUpdateNotAllowed()")))'
    uint256 private constant _SUPPLY_UPDATE_NOT_ALLOWED_SELECTOR = 0x48385ebd;

    /// @dev Event emitted when the supply of a fraktion is updated
    event SuplyUpdated(uint256 indexed id, uint256 supply);

    /// @dev Event emitted when the owner of a content changed
    event ContentOwnerUpdated(uint256 indexed id, address indexed owner);

    /// @dev 'keccak256(bytes("SuplyUpdated(uint256,uint256)"))'
    uint256 private constant _SUPPLY_UPDATED_EVENT_SELECTOR =
        0xb137aebbacc26855c231fff6d377b18aaa6397ab7c49bb7481d78a529017564d;

    /// @dev 'keccak256(bytes("ContentOwnerUpdated(uint256,address)"))'
    uint256 private constant _CONTENT_OWNER_UPDATED_EVENT_SELECTOR =
        0x93a6136b2908baf16e82828e04e9ee9af54e129f5d10e1ae48a15773b307ede4;

    /// @dev The current content token id
    uint256 private _currentContentTokenId;

    /// @dev The current callback
    FraktionTransferCallback private transferCallback;

    /// @dev Id of content to owner of this content
    mapping(uint256 => address) public owners;

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

    /**
     * @dev Register a new transaction callback
     */
    function registerNewCallback(address callbackAddr) external onlyRole(FrakRoles.ADMIN) whenNotPaused {
        transferCallback = FraktionTransferCallback(callbackAddr);
    }

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
     * @dev Batch balance of for single address
     */
    function balanceOfIdsBatch(address account, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        uint256[] memory batchBalances = new uint256[](ids.length);
        for (uint256 i; i < ids.length;) {
            unchecked {
                // TODO : Find a way to directly check _balances var without the require check
                batchBalances[i] = balanceOf(account, ids[i]);
                ++i;
            }
        }
        return batchBalances;
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

            // Iterate over each ids
            let idsOffset := ids.offset
            let length := calldataload(idsOffset)

            // Get the supplies offset
            let suppliesOffset := supplies.offset

            // Iterate over all the ids and supplies
            for { let i := 0 } lt(i, ids.length) { i := add(i, 1) } {
                let id := calldataload(add(idsOffset, mul(0x20, i)))
                let supply := calldataload(add(suppliesOffset, mul(0x20, i)))

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
            // Get the length
            let length := mload(ids)

            // Load the offset for each one of our storage pointer
            let idsOffset := add(ids, 0x20)
            let amountsOffset := add(amounts, 0x20)

            // Iterate over all the ids and amount
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let id := mload(add(idsOffset, mul(0x20, i)))
                let amount := mload(add(amountsOffset, mul(0x20, i)))

                // Get the slot to know if it's supply aware
                // Kecak (id, _isSupplyAware.slot)
                mstore(0, id)
                mstore(0x20, _isSupplyAware.slot)
                let isSupplyAware := sload(keccak256(0, 0x40))

                // Supply awaire code block
                if isSupplyAware {
                    // Get the supply slot
                    // Kecak (id, _availableSupplies.slot)
                    mstore(0, id)
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
                    let contentId := div(id, exp(2, 4))
                    // Get the owner slot
                    // Kecak (contentId, owners.slot)
                    mstore(0, contentId)
                    mstore(0x20, owners.slot)
                    // Update the owner
                    sstore(keccak256(0, 0x40), to)
                    // Log the event
                    log3(0, 0, _CONTENT_OWNER_UPDATED_EVENT_SELECTOR, contentId, to)
                }
            }
        }

        // Call our callback
        if (address(transferCallback) != address(0)) {
            transferCallback.onFraktionsTransferred(from, to, ids, amounts);
        }
    }

    /**
     * @dev Mint a new fraction of a nft
     */
    function mint(address to, uint256 id, uint256 amount) external payable onlyRole(FrakRoles.MINTER) whenNotPaused {
        _mint(to, id, amount, new bytes(0x0));
    }

    /**
     * @dev Burn a fraction of a nft
     */
    function burn(address from, uint256 id, uint256 amount) external payable onlyRole(FrakRoles.MINTER) whenNotPaused {
        _burn(from, id, amount);
    }

    /**
     * @dev Find the owner of the given content is
     */
    function ownerOf(uint256 contentId) external view returns (address) {
        return owners[contentId];
    }

    /**
     * @dev Fidn the current supply of the given token
     */
    function supplyOf(uint256 tokenId) external view returns (uint256) {
        return _availableSupplies[tokenId];
    }
}
