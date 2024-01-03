// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { ContentId } from "../libs/ContentId.sol";

/// @author @KONFeature
/// @title IPaywall
/// @notice Interface for the paywall contract
/// @custom:security-contact contact@frak.id
interface IPaywall {
    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the price isn't known for the given content
    error PriceIndexOutOfBound(uint256 priceIndex);

    /// @dev Error when the user already unlocked the article
    error ArticleAlreadyUnlocked(ContentId contentId, bytes32 articleId);

    /// @dev Error when the user already unlocked the article
    error ArticlePriceDisabled(ContentId contentId, bytes32 articleId, uint256 priceIndex);

    /// @dev Error when the price is zero
    error PriceCannotBeZero();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a user paid an article
    event PaidItemUnlocked(
        ContentId indexed contentId,
        bytes32 indexed articleId,
        address indexed user,
        uint256 paidAmount,
        uint48 allowedUntil
    );

    /* -------------------------------------------------------------------------- */
    /*                                  Structs                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Represent unlock prices for an article
    struct UnlockPrice {
        /// The price, in gwei, to access the article
        uint256 price;
        // The allowance time, in seconds, for the user to access the article, take up 4 bytes, 28 remains
        uint32 allowanceTime;
        // Check if this price is enabled or not
        bool isPriceEnabled;
    }

    /// @dev Represent content paywall
    struct ContentPaywall {
        /// The different prices to access this content
        UnlockPrice[] prices;
    }

    /// @dev Represent the unlock status for a given user
    struct UnlockStatus {
        uint48 remainingTime;
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Unlock the access to the given `articleId` on the `contentId` for the given `msg.sender`, using the given
    /// `priceIndex`
    function unlockAccess(ContentId contentId, bytes32 articleId, uint256 priceIndex) external;

    /* -------------------------------------------------------------------------- */
    /*                          External view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Get all the article prices for the given `contentId`
    /// @return prices The different prices to access the content
    function getContentPrices(ContentId contentId) external view returns (UnlockPrice[] memory prices);

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
        returns (bool isAllowed, uint256 allowedUntil);

    /* -------------------------------------------------------------------------- */
    /*                          Global paywall management                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Enable the paywall globally for the given content
    function disablePaywall(ContentId _contentId) external;

    /// @dev Add a new price for the given `_contentId`
    function addPrice(ContentId _contentId, UnlockPrice calldata price) external;

    /// @dev Update the price at the given `_priceIndex` for the given `_contentId`
    function updatePrice(ContentId _contentId, uint256 _priceIndex, UnlockPrice calldata _price) external;
}
