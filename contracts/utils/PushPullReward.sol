// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./SybelAccessControlUpgradeable.sol";

/// @dev Error throwned when the contract havn't enough founds for the withdraw
error NotEnoughFound();

/**
 * @dev Abstraction for contract that give a push / pull reward, address based
 */
/// @custom:security-contact crypto-support@sybel.co
abstract contract PushPullReward is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * Access the token that will deliver the tokens
     */
    IERC20Upgradeable internal token;

    /**
     * The pending reward for the given address
     */
    mapping(address => uint256) internal _pendingRewards;

    /**
     * @dev Event emitted when a user withdraw his pending reward
     */
    event RewardWithdrawed(address indexed user, uint256 amount);

    /**
     * Init of this contract
     */
    function __PushPullReward_init(address tokenAddr) internal onlyInitializing {
        token = IERC20Upgradeable(tokenAddr);
    }

    /**
     * Add founds for the given user
     */
    function _addFounds(address user, uint256 founds) internal {
        if (user == address(0)) revert InvalidAddress();
        _pendingRewards[user] += founds;
    }

    /**
     * Add founds for the given user
     */
    function _addFoundsUnchecked(address user, uint256 founds) internal {
        unchecked {
            _pendingRewards[user] += founds;
        }
    }

    function withdrawFounds() external virtual;

    function withdrawFounds(address user) external virtual;

    /**
     * Core logic of the withdraw method
     */
    function _withdraw(address user) internal {
        if (user == address(0)) revert InvalidAddress();
        // Ensure the user have a pending reward
        uint256 pendingReward = _pendingRewards[user];
        if (pendingReward == 0) revert NoReward();
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = token.balanceOf(address(this));
        if (pendingReward > contractBalance) revert NotEnoughFound();
        // Reset the user pending balance
        _pendingRewards[user] = 0;
        // Emit the withdraw event
        emit RewardWithdrawed(user, pendingReward);
        // Perform the transfer of the founds
        token.safeTransfer(user, pendingReward);
    }

    /**
     * Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint256) {
        if (user == address(0)) revert InvalidAddress();
        return _pendingRewards[user];
    }
}
