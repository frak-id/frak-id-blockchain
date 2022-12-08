// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "./IMinter.sol";
import "./badges/FractionCostBadges.sol";
import "../utils/SybelMath.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/MintingAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @dev Error emitted when the input supply is invalid
error InvalidSupply();

/// @dev Error emitted when the user havn't enought balance
error NotEnoughBalance();

/// @dev Error emitted when it remain some fraktion supply when wanting to increase it
error RemainingSupply();

/**
 * @dev Represent our minter contract
 * Remain to dev :
 *   - New supply increase system (each week, only if all fractions are sold)
 *   - Add allowance to the user when he mint a fraction (web2)
 */
/// @custom:security-contact crypto-support@sybel.co
contract Minter is IMinter, MintingAccessControlUpgradeable, FractionCostBadges {
    using SafeERC20Upgradeable for SybelToken;

    /**
     * @dev Access our internal tokens
     */
    SybelInternalTokens private sybelInternalTokens;

    /**
     * @dev Access our governance token
     */
    /// @custom:oz-renamed-from tokenSybelEcosystem
    SybelToken private sybelToken;

    /**
     * @dev Address of the foundation wallet
     */
    address private foundationWallet;

    /**
     * @dev Event emitted when a new content is minted
     */
    event ContentMinted(uint256 baseId, address owner);

    /**
     * @dev Event emitted when a new fraction of content is minted
     */
    event FractionMinted(uint256 fractionId, address user, uint256 amount, uint256 cost);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr, address internalTokenAddr, address foundationAddr) external initializer {
        if (frkTokenAddr == address(0) || internalTokenAddr == address(0) || foundationAddr == address(0))
            revert InvalidAddress();

        // Only for v1 deployment
        __MintingAccessControlUpgradeable_init();

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(frkTokenAddr);

        foundationWallet = foundationAddr;

        // Grant the badge updater role to the sender
        _grantRole(SybelRoles.BADGE_UPDATER, msg.sender);
    }

    /**
     * @dev Add a new content to our eco system
     */
    function addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 premiumSupply,
        uint256 goldSupply,
        uint256 diamondSupply
    ) external override onlyRole(SybelRoles.MINTER) whenNotPaused returns (uint256 contentId) {
        if (contentOwnerAddress == address(0)) revert InvalidAddress();
        if (commonSupply == 0 || commonSupply > 500 || premiumSupply > 200 || goldSupply > 50 || diamondSupply > 20)
            revert InvalidSupply();
        // Try to mint the new content
        contentId = sybelInternalTokens.mintNewContent(contentOwnerAddress);
        // Then set the supply for each token types
        uint256[] memory ids = new uint256[](4);
        ids[0] = SybelMath.buildCommonNftId(contentId);
        ids[1] = SybelMath.buildPremiumNftId(contentId);
        ids[2] = SybelMath.buildGoldNftId(contentId);
        ids[3] = SybelMath.buildDiamondNftId(contentId);
        uint256[] memory supplies = new uint256[](4);
        supplies[0] = commonSupply;
        supplies[1] = premiumSupply;
        supplies[2] = goldSupply;
        supplies[3] = diamondSupply;
        sybelInternalTokens.setSupplyBatch(ids, supplies);
        // Emit the event
        emit ContentMinted(contentId, contentOwnerAddress);
        // Return the minted content id
        return contentId;
    }

    /**
     * @dev Mint a new s nft
     */
    function mintFraction(
        uint256 id,
        address to,
        uint256 amount
    ) external override onlyRole(SybelRoles.MINTER) whenNotPaused {
        _mintFraction(id, to, amount);
    }

    /**
     * @dev Mint a new s nft for a user directly
     */
    function mintFraction(
        uint256 id,
        uint256 amount
    ) external override whenNotPaused {
        _mintFraction(id, msg.sender, amount);
    }

    /**
     * @dev Mint a new s nft
     */
    function _mintFraction(
        uint256 id,
        address to,
        uint256 amount
    ) private {
        // Get the cost of the fraction
        uint256 fractionCost = getCostBadge(id);
        uint256 totalCost = fractionCost * amount;
        // Check if the user have enough the balance
        uint256 userBalance = sybelToken.balanceOf(to);
        if (totalCost > userBalance) revert NotEnoughBalance();
        // Mint his Fraction of NFT
        sybelInternalTokens.mint(to, id, amount);
        // Transfer all the token to the fundation wallet
        sybelToken.safeTransferFrom(to, foundationWallet, totalCost);

        // Emit the event
        emit FractionMinted(id, to, amount, totalCost);
    }

    /**
     * @dev Increase the supply for a content fraction
     */
    function increaseSupply(uint256 id, uint256 newSupply) external onlyRole(SybelRoles.MINTER) whenNotPaused {
        uint256 currentSupply = sybelInternalTokens.supplyOf(id);
        if (currentSupply > 0) revert RemainingSupply();
        // Compute the supply difference
        uint256 newRealSupply = currentSupply + newSupply;
        // Mint his Fraction of NFT
        sybelInternalTokens.setSupplyBatch(SybelMath.asSingletonArray(id), SybelMath.asSingletonArray(newRealSupply));
    }

    function updateCostBadge(
        uint256 fractionId,
        uint96 badge
    ) external override onlyRole(SybelRoles.BADGE_UPDATER) whenNotPaused {
        _updateCostBadge(fractionId, badge);
    }
}
