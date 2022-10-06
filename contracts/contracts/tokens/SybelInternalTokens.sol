// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/SybelMath.sol";
import "../utils/MintingAccessControlUpgradeable.sol";

/// @custom:security-contact crypto-support@sybel.co
/// @custom:oz-upgrades-unsafe-allow external-library-linking
contract SybelInternalTokens is MintingAccessControlUpgradeable, ERC1155Upgradeable, IERC2981Upgradeable {
    // The current podcast token id
    uint256 private _currentPodcastTokenID;

    // Id of podcast to owner of this podcast
    mapping(uint256 => address) public owners;

    // Available supply of each tokens (classic, rare, epic and legendary only) by they id
    mapping(uint256 => uint256) private _availableSupplies;

    // Tell us if that token is supply aware or not
    mapping(uint256 => bool) private _isSupplyAware;

    /**
     * @dev Event emitted when a new fraction of podcast is minted
     */
    event SuplyUpdated(uint256 id, uint256 supply);

    /**
     * @dev Event emitted when the owner of a podcast changed
     */
    event PodcastOwnerUpdated(uint256 id, address owner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __ERC1155_init("https://storage.googleapis.com/sybel-io.appspot.com/json/{id}.json");
        __MintingAccessControlUpgradeable_init();
        // Set the initial podcast id
        _currentPodcastTokenID = 1;
    }

    /**
     * @dev Mint a new podcast, return the id of the built podcast
     */
    function mintNewPodcast(address podcastOwnerAddress)
        external
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
        returns (uint256)
    {
        // Get the next podcast id and increment the current podcast token id
        uint256 id = _currentPodcastTokenID + 1;
        _currentPodcastTokenID++;

        // Mint the podcast nft into the podcast owner wallet directly
        uint256 nftId = SybelMath.buildNftId(id);
        _isSupplyAware[nftId] = true;
        _availableSupplies[nftId] = 1;
        _mint(podcastOwnerAddress, nftId, 1, new bytes(0x0));

        // Return the podcast id
        return id;
    }

    /**
     * @dev Set the supply for each token ids
     */
    function setSupplyBatch(uint256[] calldata ids, uint256[] calldata supplies)
        external
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
    {
        require(ids.length == supplies.length, "SYB: Id and supplies of different length");
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
                        "SYB: Not enough available supply for mint for id"
                    );
                }
            }
        }
    }

    /**
     * @dev Handle the transfer token (so update the podcast investor, change the owner of some podcast etc)
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

            // Then check if the owner of this podcast have changed
            if (SybelMath.isPodcastNft(id)) {
                // If this token is a podcast NFT, change the owner of this podcast
                uint256 podcastId = SybelMath.extractPodcastId(id);
                owners[podcastId] = to;
                emit PodcastOwnerUpdated(podcastId, to);
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
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (salePrice > 0 && SybelMath.isPodcastRelatedToken(tokenId)) {
            // Find the address of the owner of this podcast
            address ownerAddress = owners[SybelMath.extractPodcastId(tokenId)];
            uint256 royaltyForOwner = (salePrice * 4) / 100;
            return (ownerAddress, royaltyForOwner);
        } else {
            // Otherwise, return address 0 with no royalty amount
            return (address(0), 0);
        }
    }

    /**
     * @dev Find the owner of the given podcast is
     */
    function ownerOf(uint256 podcastId) external view returns (address owner) {
        return owners[podcastId];
    }

    /**
     * @dev Fidn the current supply of the given token
     */
    function supplyOf(uint256 tokenId) external view returns (uint256 supply) {
        return _availableSupplies[tokenId];
    }

    /**
     * @dev Required extension to support access control and ERC1155
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, IERC165Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
