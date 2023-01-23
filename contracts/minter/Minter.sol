// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { IMinter } from "./IMinter.sol";
import { FractionCostBadges } from "./badges/FractionCostBadges.sol";
import { FrakMath } from "../utils/FrakMath.sol";
import { FrakRoles } from "../utils/FrakRoles.sol";
import { FraktionTokens } from "../tokens/FraktionTokens.sol";
import { FrakToken } from "../tokens/FrakTokenL2.sol";
import { MintingAccessControlUpgradeable } from "../utils/MintingAccessControlUpgradeable.sol";
import { InvalidAddress } from "../utils/FrakErrors.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @dev Error emitted when the input supply is invalid
error InvalidSupply();

/// @dev Error emitted when it remain some fraktion supply when wanting to increase it
error RemainingSupply();

/// @dev Error emitted when we only want to mint a free fraktion, and that's not a free fraktion
error ExpectingOnlyFreeFraktion();

/// @dev Error emitted when the user already have a free fraktion
error AlreadyHaveFreeFraktion();

/**
 * @dev Represent our minter contract
 * @notice Minter contract
 */
/// @custom:security-contact contact@frak.id
contract Minter is IMinter, MintingAccessControlUpgradeable, FractionCostBadges {
    using SafeERC20Upgradeable for FrakToken;
    using FrakMath for uint256;

    /**
     * @dev Access our internal tokens
     */
    FraktionTokens private fraktionTokens;

    /**
     * @dev Access our governance token
     */
    FrakToken private frakToken;

    /**
     * @dev Address of the foundation wallet
     */
    address private foundationWallet;

    /**
     * @dev Event emitted when a new content is minted
     */
    event ContentMinted(uint256 baseId, address indexed owner);

    /**
     * @dev Event emitted when a new fraction of content is minted
     */
    event FractionMinted(uint256 indexed fractionId, address indexed user, uint256 amount, uint256 cost);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr, address fraktionTokensAddr, address foundationAddr) external initializer {
        if (frkTokenAddr == address(0) || fraktionTokensAddr == address(0) || foundationAddr == address(0))
            revert InvalidAddress();

        // Only for v1 deployment
        __MintingAccessControlUpgradeable_init();

        fraktionTokens = FraktionTokens(fraktionTokensAddr);
        frakToken = FrakToken(frkTokenAddr);

        foundationWallet = foundationAddr;

        // Grant the badge updater role to the sender
        _grantRole(FrakRoles.BADGE_UPDATER, msg.sender);
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
    ) external override onlyRole(FrakRoles.MINTER) whenNotPaused returns (uint256 contentId) {
        if (contentOwnerAddress == address(0)) revert InvalidAddress();
        if (commonSupply == 0 || commonSupply > 500 || premiumSupply > 200 || goldSupply > 50 || diamondSupply > 20)
            revert InvalidSupply();
        // Try to mint the new content
        contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        // Then set the supply for each token types
        uint256[] memory ids = new uint256[](4);
        ids[0] = contentId.buildCommonNftId();
        ids[1] = contentId.buildPremiumNftId();
        ids[2] = contentId.buildGoldNftId();
        ids[3] = contentId.buildDiamondNftId();
        uint256[] memory supplies = new uint256[](4);
        supplies[0] = commonSupply;
        supplies[1] = premiumSupply;
        supplies[2] = goldSupply;
        supplies[3] = diamondSupply;
        fraktionTokens.setSupplyBatch(ids, supplies);
        // Emit the event
        emit ContentMinted(contentId, contentOwnerAddress);
        // Return the minted content id
        return contentId;
    }

    /**
     * @dev Mint a new s nft
     */
    function mintFractionForUser(
        uint256 id,
        address to,
        uint256 amount
    ) external override onlyRole(FrakRoles.MINTER) whenNotPaused {
        // Get the cost of the fraction
        uint256 totalCost = getCostBadge(id) * amount;
        // Emit the event
        emit FractionMinted(id, to, amount, totalCost);
        // Transfer the tokens
        frakToken.safeTransferFrom(to, foundationWallet, totalCost);
        // Mint his Fraction of NFT
        fraktionTokens.mint(to, id, amount);
    }

    /**
     * @dev Increase the supply for a content fraction
     */
    function increaseSupply(uint256 id, uint256 newSupply) external onlyRole(FrakRoles.MINTER) whenNotPaused {
        uint256 currentSupply = fraktionTokens.supplyOf(id);
        if (currentSupply > 0) revert RemainingSupply();
        // Compute the supply difference
        uint256 newRealSupply = currentSupply + newSupply;
        // Mint his Fraction of NFT
        fraktionTokens.setSupplyBatch(id.asSingletonArray(), newRealSupply.asSingletonArray());
    }

    /**
     * @notice  Update the cost badge for the given fraktion
     * @dev     Call to the FraktionCostBadges subclass to update the cost badge, need the right role and contract unpaused
     * @param   fractionId The id of the fraktion we will update the badge
     * @param   badge The new badge for the fraktion
     */
    function updateCostBadge(
        uint256 fractionId,
        uint96 badge
    ) external override onlyRole(FrakRoles.BADGE_UPDATER) whenNotPaused {
        _updateCostBadge(fractionId, badge);
    }

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion, only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     * @param   to  Address of the user
     */
    function mintFreeFractionForUser(uint256 id, address to) external override onlyRole(FrakRoles.MINTER) whenNotPaused {
        // Ensure it's a free fraktion
        uint256 tokenType = id.extractTokenType();
        if(tokenType != FrakMath.TOKEN_TYPE_FREE_MASK) revert ExpectingOnlyFreeFraktion();

        // Ensure the user doesn't have any free fraktion for this content yet
        uint256 userBalance = fraktionTokens.balanceOf(to, id);
        if(userBalance != 0) revert AlreadyHaveFreeFraktion();

        // If we are all good, mint the free fraktion to the user
        fraktionTokens.mint( to, id, 1);
    }
}
