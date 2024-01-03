// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { IPaywall } from "./IPaywall.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { FraktionTokens } from "../fraktions/FraktionTokens.sol";
import { ContentId } from "../libs/ContentId.sol";
import { PushPullReward } from "../utils/PushPullReward.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { NotAuthorized } from "../utils/FrakErrors.sol";

/// @author @KONFeature
/// @title Paywall
/// @notice Contract in charge of receiving paywall payment and distribute the amount to the content creator
/// @custom:security-contact contact@frak.id
contract Paywall is FrakAccessControlUpgradeable, PushPullReward, IPaywall {
    using SafeTransferLib for address;

    /// @dev The percentage of fees going to the frak labs company
    uint256 private constant FEE_PERCENT = 2;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev All the prices for a content
    /// TODO: should remove the id from the unlock price since redundant with the mapping key
    mapping(ContentId contentId => ContentPaywall) private contentPaywall;

    /// @dev Storage of allowance for a given user, on a given article
    mapping(ContentId contentId => mapping(bytes32 articleId => mapping(address user => uint256 validUntil))) private
        unlockedUntilForUser;

    /// @dev Fraktion token access
    FraktionTokens private fraktionTokens;

    /// @dev Address of the frak labs wallet
    address private frakLabsWallet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _frkTokenAddr,
        address _fraktionTokensAddr,
        address _frakLabsWalletAddr
    )
        external
        initializer
    {
        // Only for v1 deployment
        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(_frkTokenAddr);

        fraktionTokens = FraktionTokens(_fraktionTokensAddr);
        frakLabsWallet = _frakLabsWalletAddr;
    }

    /// @dev Unlock the access to the given `articleId` on the `contentId` for the given `msg.sender`, using the given
    /// `priceId`
    function unlockAccess(ContentId _contentId, bytes32 _articleId, uint256 _priceIndex) external override {
        // Check if the price is in the content
        ContentPaywall storage paywall = contentPaywall[_contentId];
        if (_priceIndex >= paywall.prices.length) {
            revert PriceIndexOutOfBound(_priceIndex);
        }

        // Check if the user has already access to the article
        mapping(address user => uint256 validUntil) storage userUnlockedUntil =
            unlockedUntilForUser[_contentId][_articleId];
        uint256 currentUnlockedUntil = userUnlockedUntil[msg.sender];
        if (currentUnlockedUntil > block.timestamp) {
            revert ArticleAlreadyUnlocked(_contentId, _articleId);
        }

        // Otherwise, fetch the price
        UnlockPrice memory unlockPrice = paywall.prices[_priceIndex];
        if (!unlockPrice.isPriceEnabled) {
            revert ArticlePriceDisabled(_contentId, _articleId, _priceIndex);
        }

        // Compute the new unlocked until
        uint256 newUnlockedUntil = block.timestamp + unlockPrice.allowanceTime;

        // Get the owner of this content
        address contentOwner = fraktionTokens.ownerOf(_contentId);
        address user = msg.sender;

        // Emit the unlock event
        emit PaidItemUnlocked(_contentId, _articleId, user, unlockPrice.price, uint48(newUnlockedUntil));

        // Transfer the FRK amount to this contract
        token.safeTransferFrom(user, address(this), unlockPrice.price);

        // Save the reward for the content owner
        _addFoundsUnchecked(contentOwner, unlockPrice.price);

        // Save the unlock status for this article
        userUnlockedUntil[user] = newUnlockedUntil;
    }

    /// @dev Get all the article prices for the given content
    /// @return prices The different prices to access the content
    function getContentPrices(ContentId _contentId) external view override returns (UnlockPrice[] memory prices) {
        ContentPaywall storage paywall = contentPaywall[_contentId];
        return paywall.prices;
    }

    /// @dev Check if the access to an `item` on a `contentId` by the given `user` is allowed
    /// @return isAllowed True if the access is allowed, false otherwise
    /// @return allowedUntil The timestamp until the access is allowed, uint48.max if the access is allowed forever
    function isReadAllowed(
        ContentId contentId,
        bytes32 articleId,
        address user
    )
        external
        view
        override
        returns (bool isAllowed, uint256 allowedUntil)
    {
        // Fetch the unlock status for the given user
        uint256 unlockedUntil = unlockedUntilForUser[contentId][articleId][user];
        if (unlockedUntil == 0) {
            return (false, 0);
        }

        // Otherwise, compare it to the current timestamp
        return (unlockedUntil > block.timestamp, unlockedUntil);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Global paywall management                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Enable the paywall globally for the given content
    function disablePaywall(ContentId _contentId) external override onlyContentOwner(_contentId) {
        // Remove all the prices
        delete contentPaywall[_contentId];
    }

    /// @dev Add a new price for the given `_contentId`
    function addPrice(
        ContentId _contentId,
        UnlockPrice calldata price
    )
        external
        override
        onlyContentOwner(_contentId)
    {
        // Check the price
        if (price.price == 0) {
            revert PriceCannotBeZero();
        }

        // Add the price
        ContentPaywall storage paywall = contentPaywall[_contentId];
        paywall.prices.push(price);
    }

    /// @dev Update the price at the given `_priceIndex` for the given `_contentId`
    function updatePrice(
        ContentId _contentId,
        uint256 _priceIndex,
        UnlockPrice calldata _price
    )
        external
        override
        onlyContentOwner(_contentId)
    {
        // Check the price
        if (_price.price == 0) {
            revert PriceCannotBeZero();
        }

        // Check if the price is in the content
        ContentPaywall storage paywall = contentPaywall[_contentId];
        if (_priceIndex >= paywall.prices.length) {
            revert PriceIndexOutOfBound(_priceIndex);
        }

        // Update the price
        paywall.prices[_priceIndex] = _price;
    }

    /// @dev Modifier to only allow the content owner to call the function
    modifier onlyContentOwner(ContentId _contentId) {
        if (fraktionTokens.ownerOf(_contentId) != msg.sender) revert NotAuthorized();
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Founds movments                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Withdraw the pending founds of the caller
    function withdrawFounds() external override {
        _withdrawWithFee(msg.sender, FEE_PERCENT, frakLabsWallet);
    }

    /// @dev Withdraw the pending founds of `user`
    function withdrawFounds(address user) external override {
        _withdrawWithFee(user, FEE_PERCENT, frakLabsWallet);
    }
}
