// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IRewarder.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../utils/PushPullReward.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Represent our referral contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Referral is SybelAccessControlUpgradeable, PushPullReward {
    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserReferred(uint256 indexed contentId, address indexed referer, address indexed referee);
    /**
     * @dev Event emitted when a user is rewarded by the referral program
     */
    event ReferralReward(uint256 indexed contentId, address indexed user, uint96 amount);

    /**
     * Mapping of content id to referee to referer
     */
    mapping(uint256 => mapping(address => address)) private contentIdToRefereeToReferer;

    /**
     * The pending referal reward for the given address
     */
    mapping(address => uint96) private userPendingReward;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address sybelTokenAddr) external initializer {
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
        // Ensure the user doesn't have a referer yet
        address actualReferer = contentIdToRefereeToReferer[contentId][user];
        require(actualReferer == address(0), "SYB: already got a referrer");
        bool isInRefererChain = isUserInRefererChain(contentId, user, referer);
        require(!isInRefererChain, "SYB: already in referee chain");
        // Check if the user isn't in the referrer chain
        // If that's got, set it and emit the event
        contentIdToRefereeToReferer[contentId][user] = referer;
        emit UserReferred(contentId, referer, user);
    }

    function isUserInRefererChain(
        uint256 contentId,
        address user,
        address referer
    ) internal returns (bool) {
        // Get the referer of our referer
        address referrerReferrer = contentIdToRefereeToReferer[contentId][referer];
        if (referrerReferrer == address(0)) {
            // If he don't have any referer, exit
            return false;
        } else if (referrerReferrer == user) {
            // If that's the same address as the user, exit
            return true;
        } else {
            // Otherwise, go down a level and check again
            return isUserInRefererChain(contentId, user, referrerReferrer);
        }
    }

    /**
     * Pay all the user referer, and return the amount paid
     */
    function payAllReferer(
        uint256 contentId,
        address user,
        uint96 amount
    ) public onlyRole(SybelRoles.REWARDER) whenNotPaused returns (uint96 totalAmount) {
        require(user != address(0), "SYBL: invalid address");
        require(amount > 0, "SYB: invalid amount");
        // Store the pending reward for this user, and emit the associated event's
        userPendingReward[user] += amount;
        emit ReferralReward(contentId, user, amount);
        // The total amount to be paid
        totalAmount = amount;
        // Check if the user got a referer
        address userReferer = contentIdToRefereeToReferer[contentId][user];
        if (userReferer != address(0) && amount > 0) {
            // If yes, recursively get all the amount to be paid for all of his referer,
            // multiplying by 0.8 each time we go up a level
            uint96 refererAmount = (amount * 4) / 5;
            totalAmount += payAllReferer(contentId, user, refererAmount);
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
