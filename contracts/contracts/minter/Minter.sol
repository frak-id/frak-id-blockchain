// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IMinter.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../badges/cost/IFractionCostBadges.sol";
import "../utils/SybelMath.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelToken.sol";
import "../utils/MintingAccessControlUpgradeable.sol";

/**
 * @dev Represent our minter contract
 * Remain to dev :
 *   - New supply increase system (each week, only if all fractions are sold)
 *   - Add allowance to the user when he mint a fraction (web2)
 */
/// @custom:security-contact crypto-support@sybel.co
contract Minter is
    IMinter,
    MintingAccessControlUpgradeable,
    PaymentBadgesAccessor
{
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
     * @dev Event emitted when a new podcast is minted
     */
    event PodcastMinted(uint256 baseId, address owner);

    /**
     * @dev Event emitted when a new fraction of podcast is minted
     */
    event FractionMinted(
        uint256 fractionId,
        address user,
        uint256 amount,
        uint256 cost
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address sybelTokenAddr,
        address internalTokenAddr,
        address listenerBadgesAddr,
        address podcastBadgesAddr,
        address fractionCostBadgesAddr,
        address foundationAddr
    ) external initializer {
        /*
        // Only for v1 deployment
        __MintingAccessControlUpgradeable_init();
        __PaymentBadgesAccessor_init(listenerBadgesAddr, podcastBadgesAddr);

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(sybelTokenAddr);
        fractionCostBadges = IFractionCostBadges(fractionCostBadgesAddr);

        foundationWallet = foundationAddr;*/
    }

    function migrateToV2(address sybelTokenAddr, address foundationAddr)
        external
        reinitializer(2)
    {
        /*
        // Only for v2 upgrade
        sybelToken = SybelToken(sybelTokenAddr);
        foundationWallet = foundationAddr;
        */
    }

    function migrateToV3(address fractionCostBadgesAddr)
        external
        reinitializer(3)
    {
        /*
        // Only for v3 upgrade
        fractionCostBadges = IFractionCostBadges(fractionCostBadgesAddr);
        */
    }

    function migrateToV4(address podcastBadgesAddr) external reinitializer(4) {
        // Only for v4 upgrade
        podcastBadges = IPodcastBadges(podcastBadgesAddr);
    }

    /**
     * @dev Add a new podcast to our eco system
     */
    function addPodcast(
        address podcastOwnerAddress,
        uint256 commonSupply,
        uint256 rareSupply,
        uint256 epicSupply,
        uint256 legendarySupply
    )
        external
        override
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
        returns (uint256)
    {
        require(
            podcastOwnerAddress != address(0),
            "SYB: Cannot add podcast for the 0 address !"
        );
        require(
            commonSupply > 0,
            "SYB: Common supply required for initial mint"
        );
        require(
            commonSupply < 500,
            "SYB: Initial common supply cant' be greater than 500"
        );
        require(
            rareSupply < 200,
            "SYB: Initial rare supply cant' be greater than 200"
        );
        require(
            epicSupply < 50,
            "SYB: Initial epic supply cant' be greater than 50"
        );
        require(
            legendarySupply < 5,
            "SYB: Initial legendary supply cant' be greater than 5"
        );
        // Try to mint the new podcast
        uint256 podcastId = sybelInternalTokens.mintNewPodcast(
            podcastOwnerAddress
        );
        // Then set the supply for each token types
        uint256[] memory ids = new uint256[](4);
        ids[0] = SybelMath.buildClassicNftId(podcastId);
        ids[1] = SybelMath.buildRareNftId(podcastId);
        ids[2] = SybelMath.buildEpicNftId(podcastId);
        ids[3] = SybelMath.buildLegendaryNftId(podcastId);
        uint256[] memory supplies = new uint256[](4);
        supplies[0] = commonSupply; // Common
        supplies[1] = rareSupply; // Rare
        supplies[2] = epicSupply; // Epic
        supplies[3] = legendarySupply; // Legendary
        sybelInternalTokens.setSupplyBatch(ids, supplies);
        // Emit the event
        emit PodcastMinted(podcastId, podcastOwnerAddress);
        // Return the minted podcast id
        return podcastId;
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
        require(
            userBalance >= totalCost,
            "SYB: Not enough balance to pay for this fraction"
        );
        // Mint his Fraction of NFT
        sybelInternalTokens.mint(to, id, amount);
        uint256 amountForFundation = (totalCost * 2) / 10;
        // Send 20% of sybl token to the foundation
        sybelToken.mint(foundationWallet, amountForFundation);
        // Send 80% to the owner
        address owner = sybelInternalTokens.ownerOf(
            SybelMath.extractPodcastId(id)
        );
        uint256 amountForOwner = totalCost - amountForFundation;
        sybelToken.transferFrom(to, owner, amountForOwner);

        // Emit the event
        emit FractionMinted(id, to, amount, totalCost);
    }

    /**
     * @dev Increase the supply for a podcast
     */
    function increaseSupply(uint256 id, uint256 newSupply)
        external
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
    {
        // Compute the supply difference
        uint256 newRealSupply = sybelInternalTokens.supplyOf(id) + newSupply;
        // Mint his Fraction of NFT
        sybelInternalTokens.setSupplyBatch(
            SybelMath.asSingletonArray(id),
            SybelMath.asSingletonArray(newRealSupply)
        );
    }
}
