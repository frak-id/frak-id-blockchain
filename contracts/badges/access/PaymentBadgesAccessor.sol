// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../payment/IListenerBadges.sol";
import "../payment/IContentBadges.sol";

/**
 * @dev Represent a contract that can access the badges
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract PaymentBadgesAccessor is Initializable {
    /**
     * @dev Access our listener badges
     */
    IListenerBadges public listenerBadges;

    /**
     * @dev Access our content badges
     */
    IContentBadges public contentBadges;

    function __PaymentBadgesAccessor_init(address listenerBadgesAddr, address contentBadgesAddr)
        internal
        onlyInitializing
    {
        listenerBadges = IListenerBadges(listenerBadgesAddr);
        contentBadges = IContentBadges(contentBadgesAddr);
    }
}
