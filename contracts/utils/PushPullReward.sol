// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {FrakAccessControlUpgradeable} from "./FrakAccessControlUpgradeable.sol";
import {NoReward, InvalidAddress, RewardTooLarge} from "./FrakErrors.sol";

/**
 * @dev Abstraction for contract that give a push / pull reward, address based
 */
/// @custom:security-contact contact@frak.id
abstract contract PushPullReward is Initializable {
    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("RewardTooLarge()")))'
    uint256 private constant _REWARD_TOO_LARGE_SELECTOR = 0x71009bf7;

    /// @dev 'bytes4(keccak256(bytes("NoReward()")))'
    uint256 private constant _NO_REWARD_SELECTOR = 0x6e992686;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a reward is added
    event RewardAdded(address indexed user, uint256 amount);

    /// @dev Event emitted when a user withdraw his pending reward
    event RewardWithdrawed(address indexed user, uint256 amount, uint256 fees);

    /// @dev 'keccak256(bytes("RewardAdded(address,uint256)"))'
    uint256 private constant _REWARD_ADDED_EVENT_SELECTOR =
        0xac24935fd910bc682b5ccb1a07b718cadf8cf2f6d1404c4f3ddc3662dae40e29;

    /// @dev 'keccak256(bytes("RewardWithdrawed(address,uint256,uint256)"))'
    uint256 private constant _REWARD_WITHDRAWAD_EVENT_SELECTOR =
        0xaeee89f8ffa85f63cb6ab3536b526d899fe7213514e54d6ca591edbe187e6866;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The pending reward for the given address
    mapping(address => uint256) internal _pendingRewards;

    /// @dev Access the token that will deliver the tokens
    IERC20Upgradeable internal token;

    /**
     * Init of this contract
     */
    function __PushPullReward_init(address tokenAddr) internal onlyInitializing {
        token = IERC20Upgradeable(tokenAddr);
    }

    /* -------------------------------------------------------------------------- */
    /*                         External virtual function's                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev For a user to directly claim their founds
     */
    function withdrawFounds() external virtual;

    /**
     * @dev For an admin to withdraw the founds of the given user
     */
    function withdrawFounds(address user) external virtual;

    /* -------------------------------------------------------------------------- */
    /*                          External view function's                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get the available founds for the given user
     */
    function getAvailableFounds(address user) external view returns (uint256) {
        assembly {
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        return _pendingRewards[user];
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Add founds for the given user
     */
    function _addFounds(address user, uint256 founds) internal {
        assembly {
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _addFoundsUnchecked(user, founds);
    }

    /**
     * @dev Add founds for the given user, without checking the operation (gas gain, usefull when founds are checked before)
     */
    function _addFoundsUnchecked(address user, uint256 founds) internal {
        assembly {
            // Emit the added event
            mstore(0x00, founds)
            log2(0, 0x20, _REWARD_ADDED_EVENT_SELECTOR, user)
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            // Store the updated reward
            sstore(rewardSlot, add(sload(rewardSlot), founds))
        }
    }

    /**
     * @dev Core logic of the withdraw method
     */
    function _withdraw(address user) internal {
        uint256 userAmount;
        assembly {
            // Check input params
            if iszero(user) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            userAmount := sload(rewardSlot)
            // Revert if no reward
            if iszero(userAmount) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Emit the witdraw event
            mstore(0x00, userAmount)
            mstore(0x20, 0)
            log2(0, 0x40, _REWARD_WITHDRAWAD_EVENT_SELECTOR, user)
            // Reset his reward
            sstore(rewardSlot, 0)
        }
        // Perform the transfer of the founds
        token.transfer(user, userAmount);
    }

    /**
     * @dev Core logic of the withdraw method, but with fee this time
     * @notice If that's the fee recipient performing the call, withdraw without fee's (otherwise, infinite loop required to get all the frk foundation fee's)
     */
    function _withdrawWithFee(address user, uint256 feePercent, address feeRecipient) internal {
        uint256 feesAmount;
        uint256 userAmount;
        assembly {
            // Check input params
            if or(iszero(user), iszero(feePercent)) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            if gt(feePercent, 10) {
                mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Get the current pending reward
            // Kecak (user, _pendingRewards.slot)
            mstore(0, user)
            mstore(0x20, _pendingRewards.slot)
            let rewardSlot := keccak256(0, 0x40)
            // Get the slot for the fee recipient rewards
            mstore(0, feeRecipient)
            let feeRecipientSlot := keccak256(0, 0x40)
            // Get the current user pending reward
            let pendingReward := sload(rewardSlot)
            // Revert if no reward
            if iszero(pendingReward) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Compute the fee's amount
            switch eq(feeRecipient, user)
            case 1 {
                // If the fee's recipient is the caller, no fee's
                userAmount := pendingReward
            }
            default {
                // Otherwise, apply the fee's percentage
                feesAmount := div(mul(pendingReward, feePercent), 100)
                userAmount := sub(pendingReward, feesAmount)
            }
            // Reset the user reward
            sstore(rewardSlot, 0)
            // Store the fee recipient reward (if any only)
            if feesAmount { sstore(feeRecipientSlot, add(sload(feeRecipientSlot), feesAmount)) }
            // Emit the witdraw event
            mstore(0x00, userAmount)
            mstore(0x20, feesAmount)
            log2(0, 0x40, _REWARD_WITHDRAWAD_EVENT_SELECTOR, user)
        }
        // Perform the transfer of the founds
        token.transfer(user, userAmount);
    }
}
