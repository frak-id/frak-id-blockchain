// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IRewarder.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Represent our referral contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Referral is SybelAccessControlUpgradeable {
    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserReferred(uint256 podcastId, address referer, address referee);
    /**
     * @dev Event emitted when a user is rewarded by the referral program
     */
    event ReferralReward(uint256 podcastId, address user, uint256 amount);
    /**
     * @dev Event emitted when a user withdraw his pending reward
     */
    event ReferralRewardWithdrawed(address user, uint256 amount);

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * Mapping of podcast id to referee to referer
     */
    mapping(uint256 => mapping(address => address)) private podcastIdToRefereeToReferer;

    /**
     * The pending referal reward for the given address
     */
    mapping(address => uint256) private userPendingReward;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address sybelTokenAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Init our sybel token
        sybelToken = SybelToken(sybelTokenAddr);
    }

    /**
     * @dev Update the listener snft amount
     */
    function userReferred(
        uint256 podcastId,
        address user,
        address referer
    ) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        // Ensure the user doesn't have a referer yet
        address actualReferer = podcastIdToRefereeToReferer[podcastId][user];
        require(actualReferer == address(0), "SYB: The user already got a referer for this podcast");
        bool isInRefererChain = isUserInRefererChain(podcastId, user, referer);
        require(!isInRefererChain, "SYB: The user is already in the referrer referee chain");
        // Check if the user isn't in the referrer chain
        // If that's got, set it and emit the event
        podcastIdToRefereeToReferer[podcastId][user] = referer;
        emit UserReferred(podcastId, referer, user);
    }

    function isUserInRefererChain(
        uint256 podcastId,
        address user,
        address referer
    ) internal returns (bool) {
        // Get the referer of our referer
        address referrerReferrer = podcastIdToRefereeToReferer[podcastId][referer];
        if (referrerReferrer == address(0)) {
            // If he don't have any referer, exit
            return false;
        } else if (referrerReferrer == user) {
            // If that's the same address as the user, exit
            return true;
        } else {
            // Otherwise, go down a level and check again
            return isUserInRefererChain(podcastId, user, referrerReferrer);
        }
    }

    /**
     * Pay all the user referer, and return the amount paid
     */
    function payAllReferer(
        uint256 podcastId,
        address user,
        uint256 amount
    ) public onlyRole(SybelRoles.ADMIN) whenNotPaused returns (uint256 totalAmount) {
        require(user != address(0), "SYB: Can't pay referrer for the 0 address");
        require(amount > 0, "SYB: Can't pay referrer with 0 as amount");
        // Store the pending reward for this user, and emit the associated event's
        userPendingReward[user] += amount;
        emit ReferralReward(podcastId, user, amount);
        // The total amount to be paid
        totalAmount = amount;
        // Check if the user got a referer
        address userReferer = podcastIdToRefereeToReferer[podcastId][user];
        if (userReferer != address(0) && amount > 0) {
            // If yes, recursively get all the amount to be paid for all of his referer,
            // dividing by 2 each time we go up a level
            uint256 refererAmount = amount / 2;
            totalAmount += payAllReferer(podcastId, user, refererAmount);
        }
        // Then return the amount to be paid
        return totalAmount;
    }

    /**
     * Withdraw the user pending founds
     */
    function withdrawFounds(address user) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        require(user != address(0), "SYB: Can't withdraw referral founds for the 0 address");
        // Ensure the user have a pending reward
        uint256 pendingReward = userPendingReward[user];
        require(pendingReward > 0, "SYB: The user havn't any pending reward");
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = sybelToken.balanceOf(address(this));
        require(contractBalance > pendingReward, "SYB: Contract haven't enought found");
        // Reset the user pending balance
        userPendingReward[user] = 0;
        // Perform the transfer of the founds
        sybelToken.transfer(user, pendingReward);
    }
}
