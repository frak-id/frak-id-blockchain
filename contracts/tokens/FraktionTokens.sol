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

/// @custom:security-contact contact@frak.id
/// @custom:oz-upgrades-unsafe-allow external-library-linking
contract FraktionTokens is MintingAccessControlUpgradeable, ERC1155Upgradeable {
    using FrakMath for uint256;

    // The current content token id
    uint256 private _currentContentTokenId;

    // The current callback
    FraktionTransferCallback private transferCallback;

    // Id of content to owner of this content
    mapping(uint256 => address) public owners;

    // Available supply of each tokens (classic, rare, epic and legendary only) by they id
    mapping(uint256 => uint256) private _availableSupplies;

    // Tell us if that token is supply aware or not
    mapping(uint256 => bool) private _isSupplyAware;

    /**
     * @dev Event emitted when the supply of a fraktion is updated
     */
    event SuplyUpdated(uint256 indexed id, uint256 supply);

    /**
     * @dev Event emitted when the owner of a content changed
     */
    event ContentOwnerUpdated(uint256 indexed id, address indexed owner);

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
     * Register a new transaction callback
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
        id = ++_currentContentTokenId;

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
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
        if (ids.length == 0 || ids.length != supplies.length) revert InvalidArray();
        // Iterate over each ids and increment their supplies
        for (uint256 i; i < ids.length;) {
            uint256 id = ids[i];

            // We can't increase the supply of free fraktion and of NFT fraktion
            uint8 tokenType = id.extractTokenType();
            if (tokenType == FrakMath.TOKEN_TYPE_FREE_MASK || tokenType == FrakMath.TOKEN_TYPE_NFT_MASK) {
                revert SupplyUpdateNotAllowed();
            }

            // Update our supply if we are all good
            _availableSupplies[id] = supplies[i];
            _isSupplyAware[id] = true;
            // Emit the supply update event
            emit SuplyUpdated(id, supplies[i]);
            // Increase our counter
            unchecked {
                ++i;
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
        // In the case we are sending the token to a given wallet
        for (uint256 i; i < ids.length;) {
            uint256 id = ids[i];

            if (_isSupplyAware[id]) {
                // Update each supplies
                if (from == address(0)) {
                    // Ensure we got enough supply
                    if (amounts[i] > _availableSupplies[id]) revert InsuficiantSupply();
                    // If it's a minted token
                    unchecked {
                        _availableSupplies[id] -= amounts[i];
                    }
                } else if (to == address(0)) {
                    // If it's a burned token, increase th available supply
                    unchecked {
                        _availableSupplies[id] += amounts[i];
                    }
                }
            }

            // Then check if the owner of this content have changed
            if (id.isContentNft()) {
                // If this token is a content NFT, change the owner of this content
                uint256 contentId = id.extractContentId();
                owners[contentId] = to;
                emit ContentOwnerUpdated(contentId, to);
            }
            // Increase our counter
            unchecked {
                ++i;
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

    /**
     * @dev Fix the supply for each token id's
     */
    function fixSupplyBatch(uint256[] calldata ids) external onlyRole(FrakRoles.ADMIN) whenNotPaused {
        // In the case we are sending the token to a given wallet
        for (uint256 i; i < ids.length;) {
            uint256 id = ids[i];

            // Get the token type
            uint8 tokenType = id.extractTokenType();

            // If it shouldn't be supply aware, check if it was set
            if (tokenType == FrakMath.TOKEN_TYPE_FREE_MASK) {
                bool isSupplyAware = _isSupplyAware[id];
                // Reset the variable if it was supply aware
                if (isSupplyAware) {
                    _isSupplyAware[id] = false;
                    _availableSupplies[id] = 0;
                }
            } else if (tokenType == FrakMath.TOKEN_TYPE_NFT_MASK && _availableSupplies[id] > 0) {
                // If that's an nft, the supply should remain to 0
                _availableSupplies[id] = 0;
            }

            // Increase our counter
            unchecked {
                ++i;
            }
        }
    }
}
