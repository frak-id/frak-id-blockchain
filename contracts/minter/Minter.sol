// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IMinter.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../badges/cost/IFractionCostBadges.sol";
import "../utils/SybelMath.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/MintingAccessControlUpgradeable.sol";

/**
 * @dev Represent our minter contract
 * Remain to dev :
 *   - New supply increase system (each week, only if all fractions are sold)
 *   - Add allowance to the user when he mint a fraction (web2)
 */
/// @custom:security-contact crypto-support@sybel.co
contract Minter is IMinter, MintingAccessControlUpgradeable, PaymentBadgesAccessor {
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
     * @dev Access our fraction cost badges
     */
    IFractionCostBadges public fractionCostBadges;

    /**
     * @dev Address of the foundation wallet
     */
    address public foundationWallet;

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

    function initialize(
        address sybelTokenAddr,
        address internalTokenAddr,
        address listenerBadgesAddr,
        address contentBadgesAddr,
        address fractionCostBadgesAddr,
        address foundationAddr
    ) external initializer {
        /*
        // Only for v1 deployment
        __MintingAccessControlUpgradeable_init();
        __PaymentBadgesAccessor_init(listenerBadgesAddr, contentBadgesAddr);

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(sybelTokenAddr);
        fractionCostBadges = IFractionCostBadges(fractionCostBadgesAddr);

        foundationWallet = foundationAddr;*/
    }

    function migrateToV2(address sybelTokenAddr, address foundationAddr) external reinitializer(2) {
        /*
        // Only for v2 upgrade
        sybelToken = SybelToken(sybelTokenAddr);
        foundationWallet = foundationAddr;
        */
    }

    function migrateToV3(address fractionCostBadgesAddr) external reinitializer(3) {
        /*
        // Only for v3 upgrade
        fractionCostBadges = IFractionCostBadges(fractionCostBadgesAddr);
        */
    }

    function migrateToV4(address contentBadgesAddr) external reinitializer(4) {
        // Only for v4 upgrade
        contentBadges = IContentBadges(contentBadgesAddr);
    }

    /**
     * @dev Add a new content to our eco system
     */
    function addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 rareSupply,
        uint256 epicSupply,
        uint256 legendarySupply
    ) external override onlyRole(SybelRoles.MINTER) whenNotPaused returns (uint256 contentId) {
        require(contentOwnerAddress != address(0), "SYB: invalid address");
        require(commonSupply > 0, "SYB: invalid common supply");
        require(commonSupply < 500, "SYB: invalid common supply");
        require(rareSupply < 200, "SYB: invalid rare supply");
        require(epicSupply < 50, "SYB: invalid epic supply");
        require(legendarySupply < 5, "SYB: invalid legendary supply");
        // Try to mint the new content
        contentId = sybelInternalTokens.mintNewContent(contentOwnerAddress);
        // Then set the supply for each token types
        uint256[] memory ids = new uint256[](4);
        ids[0] = SybelMath.buildCommonNftId(contentId);
        ids[1] = SybelMath.buildPremiumNftId(contentId);
        ids[2] = SybelMath.buildGoldNftId(contentId);
        ids[3] = SybelMath.buildDiamondNftId(contentId);
        uint256[] memory supplies = new uint256[](4);
        supplies[0] = commonSupply; // Common
        supplies[1] = rareSupply; // Rare
        supplies[2] = epicSupply; // Epic
        supplies[3] = legendarySupply; // Legendary
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
        // Get the cost of the fraction
        uint256 fractionCost = fractionCostBadges.getBadge(id);
        uint256 totalCost = fractionCost * amount;
        // Check if the user have enough the balance
        uint256 userBalance = sybelToken.balanceOf(to);
        require(userBalance >= totalCost, "SYB: not enough balance");
        // Mint his Fraction of NFT
        sybelInternalTokens.mint(to, id, amount);
        uint256 amountForFundation = (totalCost * 2) / 10;
        // Send 20% of sybl token to the foundation
        sybelToken.mint(foundationWallet, amountForFundation);
        // Send 80% to the owner
        address owner = sybelInternalTokens.ownerOf(SybelMath.extractContentId(id));
        uint256 amountForOwner = totalCost - amountForFundation;
        sybelToken.transferFrom(to, owner, amountForOwner);

        // Emit the event
        emit FractionMinted(id, to, amount, totalCost);
    }

    /**
     * @dev Increase the supply for a content fraction
     */
    function increaseSupply(uint256 id, uint256 newSupply) external onlyRole(SybelRoles.MINTER) whenNotPaused {
        uint256 currentSupply = sybelInternalTokens.supplyOf(id);
        require(currentSupply == 0, "SYB: fraction remain");
        // Compute the supply difference
        uint256 newRealSupply = currentSupply + newSupply;
        // Mint his Fraction of NFT
        sybelInternalTokens.setSupplyBatch(SybelMath.asSingletonArray(id), SybelMath.asSingletonArray(newRealSupply));
    }
}
