// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @author @KONFeature
/// @title IReferralPool
/// @notice Interface for the referral pool contract
/// @custom:security-contact contact@frak.id
interface IReferralPool {
    /// @dev Exception throwned when the user already got a referer
    error AlreadyGotAReferer();
    /// @dev Exception throwned when the user is already in the referer chain
    error AlreadyInRefererChain();

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserReferred(uint256 indexed contentId, address indexed referer, address indexed referee);

    /**
     * @dev Event emitted when a user is rewarded by the referral program
     */
    event ReferralReward(uint256 contentId, address user, uint256 amount);

    /**
     * @dev Update the listener snft amount
     */
    function userReferred(uint256 contentId, address user, address referer) external payable;

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
        returns (uint256 totalAmount);
}
