// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Abstraction for contract that give a push / pull reward, address based
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract PushPullReward is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * The pending reward for the given address
     */
    mapping(address => uint96) private pendingRewards;

    /**
     * Access the token that will deliver the tokens
     */
    IERC20Upgradeable token;

    /**
     * @dev Event emitted when a user withdraw his pending reward
     */
    event RewardWithdrawed(address indexed user, uint96 amount);

    /**
     * Init of this contract
     */
    function __PushPullReward_init(address tokenAddr) internal onlyInitializing {
        token = IERC20Upgradeable(tokenAddr);
    }

    /**
     * Add founds for the given user
     */
    function _addFounds(address user, uint96 founds) internal {
        require(user != address(0), "SYB: invalid address");
        pendingRewards[user] += founds;
    }

    function withdrawFounds() external virtual;

    function withdrawFounds(address user) external virtual;

    /**
     * Core logic of the withdraw method
     */
    function _withdraw(address user) internal {
        require(user != address(0), "SYB: invalid address");
        // Ensure the user have a pending reward
        uint96 pendingReward = pendingRewards[user];
        require(pendingReward > 0, "SYB: no pending reward");
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > pendingReward, "SYB: not enough founds");
        // Reset the user pending balance
        pendingRewards[user] = 0;
        // Emit the withdraw event
        emit RewardWithdrawed(user, pendingReward);
        // Perform the transfer of the founds
        token.safeTransfer(user, pendingReward);
    }

    /**
     * Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint96) {
        require(user != address(0), "SYB: invalid address");
        return pendingRewards[user];
    }
}
