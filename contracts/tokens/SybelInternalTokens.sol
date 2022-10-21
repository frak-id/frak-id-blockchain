// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/SybelMath.sol";
import "../utils/MintingAccessControlUpgradeable.sol";

/// @custom:security-contact crypto-support@sybel.co
/// @custom:oz-upgrades-unsafe-allow external-library-linking
contract SybelInternalTokens is MintingAccessControlUpgradeable, ERC1155Upgradeable {
    using SybelMath for uint256;

    // The current content token id
    uint256 private _currentContentTokenId;

    // Id of content to owner of this content
    mapping(uint256 => address) public owners;

    // Available supply of each tokens (classic, rare, epic and legendary only) by they id
    mapping(uint256 => uint256) private _availableSupplies;

    // Tell us if that token is supply aware or not
    mapping(uint256 => bool) private _isSupplyAware;

    /**
     * @dev Event emitted when a new fraction of content is minted
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

    function initialize() external initializer {
        __ERC1155_init("https://storage.googleapis.com/sybel-io.appspot.com/json/{id}.json");
        __MintingAccessControlUpgradeable_init();
        // Set the initial content id
        _currentContentTokenId = 1;
    }

    /**
     * @dev Mint a new content, return the id of the built content
     */
    function mintNewContent(address ownerAddress)
        external
        onlyRole(SybelRoles.MINTER)
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
    function balanceOfIdsBatch(address account, uint256[] memory ids)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        uint256[] memory batchBalances = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; ++i) {
            batchBalances[i] = balanceOf(account, ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev Set the supply for each token ids
     */
    function setSupplyBatch(uint256[] calldata ids, uint256[] calldata supplies)
        external
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
    {
        require(ids.length == supplies.length, "SYB: invalid array length");
        // Iterate over each ids and increment their supplies
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];

            _availableSupplies[id] = supplies[i];
            _isSupplyAware[id] = true;
            // Emit the supply update event
            emit SuplyUpdated(id, supplies[i]);
        }
    }

    /**
     * @dev Perform some check before the transfer token
     */
    function _beforeTokenTransfer(
        address,
        address from,
        address,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal view override whenNotPaused {
        for (uint256 i = 0; i < ids.length; ++i) {
            if (from == address(0)) {
                // Only allow minter to perform mint operation
                _checkRole(SybelRoles.MINTER);
                if (_isSupplyAware[ids[i]]) {
                    require(
                        amounts[i] <= _availableSupplies[ids[i]],
                        "SYB: Not enough supply"
                    );
                }
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
    ) internal override {
        // In the case we are sending the token to a given wallet
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];

            if (_isSupplyAware[id]) {
                if (from == address(0)) {
                    // If it's a minted token
                    _availableSupplies[id] -= amounts[i];
                } else if (to == address(0)) {
                    // If it's a burned token
                    _availableSupplies[id] += amounts[i];
                }
            }

            // Then check if the owner of this content have changed
            if (id.isContentNft()) {
                // If this token is a content NFT, change the owner of this content
                uint256 contentId = id.extractContentId();
                owners[contentId] = to;
                emit ContentOwnerUpdated(contentId, to);
            }
        }
    }

    /**
     * @dev Mint a new fraction of a nft
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyRole(SybelRoles.MINTER) whenNotPaused {
        _mint(to, id, amount, new bytes(0x0));
    }

    /**
     * @dev Burn a fraction of a nft
     */
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external onlyRole(SybelRoles.MINTER) whenNotPaused {
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
