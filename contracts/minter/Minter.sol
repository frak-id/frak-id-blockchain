// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {IMinter} from "./IMinter.sol";
import {FractionCostBadges} from "./badges/FractionCostBadges.sol";
import {FrakMath} from "../utils/FrakMath.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {FraktionTokens} from "../tokens/FraktionTokens.sol";
import {FrakToken} from "../tokens/FrakTokenL2.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {InvalidAddress} from "../utils/FrakErrors.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @author  @KONFeature
 * @title   Minter
 * @notice  This contract will mint new content on the ecosytem, and mint fraktions for the user
 * @dev     Communicate with the FrkToken and FraktionTokens contract to handle minting of content and fraktions
 * @custom:security-contact contact@frak.id
 */
contract Minter is IMinter, MintingAccessControlUpgradeable, FractionCostBadges {
    using SafeERC20Upgradeable for FrakToken;
    using FrakMath for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                   Error's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Error emitted when the input supply is invalid
    error InvalidSupply();

    /// @dev Error emitted when it remain some fraktion supply when wanting to increase it
    error RemainingSupply();

    /// @dev Error emitted when we only want to mint a free fraktion, and that's not a free fraktion
    error ExpectingOnlyFreeFraktion();

    /// @dev Error emitted when the user already have a free fraktion
    error AlreadyHaveFreeFraktion();

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("InvalidSupply()")))'
    uint256 private constant _INVALID_SUPPLY_SELECTOR = 0x15ae6727;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a new content is minted
    event ContentMinted(uint256 baseId, address indexed owner);

    /// @dev Event emitted when a new fraktion for a content is minted
    event FractionMinted(uint256 indexed fractionId, address indexed user, uint256 amount, uint256 cost);

    /// @dev 'keccak256(bytes("ContentMinted(uint256,address)"))'
    uint256 private constant _CONTENT_MINTED_EVENT_SELECTOR =
        0x660494162a7aab2356c74a0a63c109a0a2ac6ac9d3b95415756bac61af417ecb;

    /// @dev 'keccak256(bytes("FractionMinted(uint256,address,uint256,uint256)"))'
    uint256 private constant _FRACTION_MINTED_EVENT_SELECTOR =
        0x660494162a7aab2356c74a0a63c109a0a2ac6ac9d3b95415756bac61af417ecb;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Reference to the fraktion tokens contract (ERC1155)
    FraktionTokens private fraktionTokens;

    /// @dev Reference to the Frak token contract (ERC20)
    FrakToken private frakToken;

    /// @dev Address of our foundation wallet (for fee's payment)
    address private foundationWallet;

    /* -------------------------------------------------------------------------- */
    /*                                  Function                                  */
    /* -------------------------------------------------------------------------- */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initial constructor of our minter contract (like constructor but for upgradeable contract)
     * @dev     Will only run on first init, check the address as param, and then same all the param
     * @param   frkTokenAddr  The address of the FrkToken contract
     * @param   fraktionTokensAddr  The address of the FraktionTokens contract
     * @param   foundationAddr  The foundation wallet address
     */
    function initialize(address frkTokenAddr, address fraktionTokensAddr, address foundationAddr)
        external
        initializer
    {
        if (frkTokenAddr == address(0) || fraktionTokensAddr == address(0) || foundationAddr == address(0)) {
            revert InvalidAddress();
        }

        // Only for v1 deployment
        __MintingAccessControlUpgradeable_init();

        fraktionTokens = FraktionTokens(fraktionTokensAddr);
        frakToken = FrakToken(frkTokenAddr);

        foundationWallet = foundationAddr;

        // Grant the badge updater role to the sender
        _grantRole(FrakRoles.BADGE_UPDATER, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice  Mint a new content to the FrkEcosystem
     * @dev     Will ensure the role and contract state, then the param, and finally call the FraktionTokens contract to mint the new content
     * @param   contentOwnerAddress  The address of the owner of the given content
     * @param   commonSupply  The supply desired for each common fraktion of this content
     * @param   premiumSupply  The supply desired for each premium fraktion of this content
     * @param   goldSupply  The supply desired for each gold fraktion of this content
     * @param   diamondSupply  The supply desired for each diamond fraktion of this content
     * @return  contentId  The id of the freshly minted content
     */
    function addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 premiumSupply,
        uint256 goldSupply,
        uint256 diamondSupply
    ) external payable override onlyRole(FrakRoles.MINTER) whenNotPaused returns (uint256 contentId) {
        assembly {
            // Check owner address
            if iszero(contentOwnerAddress) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Check supplies
            if or(
                or(iszero(commonSupply), gt(commonSupply, 500)),
                or(or(gt(premiumSupply, 200), gt(goldSupply, 50)), gt(diamondSupply, 20))
            ) {
                mstore(0x00, _INVALID_SUPPLY_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        // Try to mint the new content
        contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        // Then set the supply for each token types
        uint256[] memory ids = new uint256[](4);
        uint256[] memory supplies = new uint256[](4);
        assembly {
            // Store the ids
            mstore(add(ids, 0x20), or(mul(contentId, exp(2, 4)), 3))
            mstore(add(ids, 0x40), or(mul(contentId, exp(2, 4)), 4))
            mstore(add(ids, 0x60), or(mul(contentId, exp(2, 4)), 5))
            mstore(add(ids, 0x80), or(mul(contentId, exp(2, 4)), 6))
            // Store the supplies
            mstore(add(supplies, 0x20), commonSupply)
            mstore(add(supplies, 0x40), premiumSupply)
            mstore(add(supplies, 0x60), goldSupply)
            mstore(add(supplies, 0x80), diamondSupply)
        }
        fraktionTokens.setSupplyBatch(ids, supplies);
        // Emit the event
        emit ContentMinted(contentId, contentOwnerAddress);
        // Return the minted content id
        return contentId;
    }

    /**
     * @notice  Mint a new fraktion for the given amount and user
     * @dev     Will compute the fraktion price, ensure the user have enough Frk to buy it, if try, perform the transfer and mint the fraktion
     * @param   id  The id of the fraktion to be minted for the user
     * @param   to  The address on which we will mint the fraktion
     * @param   amount  The amount of fraktion to be minted for the user
     */
    function mintFractionForUser(uint256 id, address to, uint256 amount)
        external
        payable
        override
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
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
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion, only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     * @param   to  Address of the user
     */
    function mintFreeFraktionForUser(uint256 id, address to)
        external
        payable
        override
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
        // Ensure it's a free fraktion
        uint256 tokenType = id.extractTokenType();
        if (tokenType != FrakMath.TOKEN_TYPE_FREE_MASK) revert ExpectingOnlyFreeFraktion();

        // Ensure the user doesn't have any free fraktion for this content yet
        uint256 userBalance = fraktionTokens.balanceOf(to, id);
        if (userBalance != 0) revert AlreadyHaveFreeFraktion();

        // If we are all good, mint the free fraktion to the user
        fraktionTokens.mint(to, id, 1);
    }

    /**
     * @notice  Increase the total supply for the given fraktion id
     * @dev     Will call our FraktionTokens contract and increase the supply for the given fraktion, only if all of it have been minted
     * @param   id  The id of the fraktion for which we want to increase the supply
     * @param   newSupply  The supply we wan't to append for this fraktion
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
    function updateCostBadge(uint256 fractionId, uint96 badge)
        external
        override
        onlyRole(FrakRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateCostBadge(fractionId, badge);
    }
}
