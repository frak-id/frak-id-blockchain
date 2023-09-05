// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakRoles } from "../../roles/FrakRoles.sol";
import { PushPullReward } from "../../utils/PushPullReward.sol";
import { FrakAccessControlUpgradeable } from "../../roles/FrakAccessControlUpgradeable.sol";
import { InvalidAddress, NoReward } from "../../utils/FrakErrors.sol";
import { IReferralPool } from "./IReferralPool.sol";

/// @author @KONFeature
/// @title ReferralPool
/// @notice Contract in charge of managing the referral program
/// @custom:security-contact contact@frak.id
contract ReferralPool is IReferralPool, FrakAccessControlUpgradeable, PushPullReward {
    /// @dev The minimum reward is 1 mwei, to prevent iteration on really small amount
    uint256 internal constant MINIMUM_REWARD = 1_000_000;

    /// &dev The maximal referal depth we can pay
    uint256 internal constant MAX_DEPTH = 10;

    /// @dev Mapping of content id, to referee, to referer
    mapping(uint256 contentId => mapping(address referee => address referrer)) private contentIdToRefereeToReferer;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr) external initializer {
        if (frkTokenAddr == address(0)) revert InvalidAddress();

        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(frkTokenAddr);
    }

    /**
     * @dev Update the listener snft amount
     */
    function userReferred(
        uint256 contentId,
        address user,
        address referer
    )
        external
        payable
        onlyRole(FrakRoles.ADMIN)
    {
        if (user == address(0) || referer == address(0) || user == referer) {
            revert InvalidAddress();
        }
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
    )
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        returns (uint256 totalAmount)
    {
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

    function withdrawFounds() external virtual override {
        _withdraw(msg.sender);
    }

    function withdrawFounds(address user) external virtual override {
        _withdraw(user);
    }
}
