// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../utils/SybelMath.sol";
import "../../utils/SybelRoles.sol";
import "../../tokens/SybelInternalTokens.sol";
import "../../utils/PushPullReward.sol";
import "../../utils/SybelAccessControlUpgradeable.sol";

/// @dev Exception throwned when the user already got a referer
error AlreadyGotAReferer();
/// @dev Exception throwned when the user is already in the referer chain
error AlreadyInRefererChain();

/**
 * @dev Represent our referral contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract ReferralPool is SybelAccessControlUpgradeable, PushPullReward {
    // The minimum reward is 1 mwei, to prevent iteration on really small amount
    uint24 internal constant MINIMUM_REWARD = 1_000_000;

    // The maximal referal depth we can pay
    uint8 internal constant MAX_DEPTH = 10;

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserReferred(uint256 indexed contentId, address indexed referer, address indexed referee);

    /**
     * @dev Event emitted when a user is rewarded by the referral program
     */
    event ReferralReward(uint256 contentId, address user, uint256 amount);

    /**
     * Mapping of content id to referee to referer
     */
    mapping(uint256 => mapping(address => address)) private contentIdToRefereeToReferer;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address sybelTokenAddr) external initializer {
        if (syblTokenAddr == address(0)) revert InvalidAddress();

        __SybelAccessControlUpgradeable_init();
        __PushPullReward_init(sybelTokenAddr);
    }

    /**
     * @dev Update the listener snft amount
     */
    function userReferred(
        uint256 contentId,
        address user,
        address referer
    ) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        if (user == address(0) || referer == address(0) || user == referer) revert InvalidAddress();
        // Get our content referer chain (to prevent multi kecack hash each time we access it)
        mapping(address => address) storage contentRefererChain = contentIdToRefereeToReferer[contentId];

        // Ensure the user doesn't have a referer yet
        address actualReferer = contentRefererChain[user];
        if (actualReferer != address(0)) revert AlreadyGotAReferer();

        // Then, explore our referer chain to find a potential loop, or just the last address
        address refererExploration = contentRefererChain[referer];
        while (refererExploration != address(0) && refererExploration != user) {
            refererExploration = contentRefererChain[refererExploration];
        }
        if (refererExploration == user) revert AlreadyInRefererChain();

        // If that's got, set it and emit the event
        contentRefererChain[user] = referer;
        emit UserReferred(contentId, referer, user);
    }

    /**
     * Pay all the user referer, and return the amount paid
     */
    function payAllReferer(
        uint256 contentId,
        address user,
        uint256 amount
    ) public onlyRole(SybelRoles.REWARDER) whenNotPaused returns (uint256 totalAmount) {
        if (user == address(0)) revert InvalidAddress();
        if (amount == 0) revert NoReward();
        // Get our content referer chain (to prevent multi kecack hash each time we access it)
        mapping(address => address) storage contentRefererChain = contentIdToRefereeToReferer[contentId];
        // Check if the user got a referer
        address userReferer = contentRefererChain[user];
        uint256 depth;
        while (userReferer != address(0) && depth < MAX_DEPTH && amount > MINIMUM_REWARD) {
            // Store the pending reward for this user referrer, and emit the associated event's
            _addFoundsUnchecked(userReferer, amount);
            emit ReferralReward(contentId, userReferer, amount);
            // Then increase the total rewarded amount, and prepare the amount for the next referer
            unchecked {
                // Increase the total amount to be paid
                totalAmount += amount;
                // If yes, recursively get all the amount to be paid for all of his referer,
                // multiplying by 0.8 each time we go up a level
                amount = (amount * 4) / 5;
                // Increase our depth
                ++depth;
            }
            // Finally, fetch the referer of the previous referer
            userReferer = contentRefererChain[userReferer];
        }
        // Then return the amount to be paid
        return totalAmount;
    }

    function withdrawFounds() external virtual override whenNotPaused {
        _withdraw(msg.sender);
    }

    function withdrawFounds(address user) external virtual override onlyRole(SybelRoles.ADMIN) whenNotPaused {
        _withdraw(user);
    }
}
