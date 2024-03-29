// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { IRewarder } from "./IRewarder.sol";
import { ContentBadges } from "./badges/ContentBadges.sol";
import { ListenerBadges } from "./badges/ListenerBadges.sol";
import { IContentPool } from "./contentPool/IContentPool.sol";
import { IReferralPool } from "./referralPool/IReferralPool.sol";
import { ContentId } from "../libs/ContentId.sol";
import { FraktionId } from "../libs/FraktionId.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { RewardAccounter } from "./RewardAccounter.sol";
import { FraktionTokens } from "../fraktions/FraktionTokens.sol";
import { IFrakToken } from "../tokens/IFrakToken.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { InvalidAddress, InvalidArray, RewardTooLarge } from "../utils/FrakErrors.sol";
import { PushPullReward } from "../utils/PushPullReward.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title Rewarder
/// @notice Contract in charge of managing the reward for the user / creator
/// @custom:security-contact contact@frak.id
contract Rewarder is
    IRewarder,
    FrakAccessControlUpgradeable,
    ContentBadges,
    ListenerBadges,
    PushPullReward,
    Multicallable
{
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    // The cap of frak token we can mint for the reward
    uint256 private constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint256 private constant SINGLE_REWARD_CAP = 50_000 ether;

    // Maximum data we can treat in a batch manner
    uint256 private constant MAX_BATCH_AMOUNT = 20;
    uint256 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

    // Maximum data we can treat in a batch manner
    uint256 private constant CONTENT_TYPE_VIDEO = 1;
    uint256 private constant CONTENT_TYPE_PODCAST = 2;
    uint256 private constant CONTENT_TYPE_MUSIC = 3;
    uint256 private constant CONTENT_TYPE_STREAMING = 4;

    /// @dev The percentage of fee's going to the frak labs company
    uint256 private constant FEE_PERCENT = 2;

    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("InvalidReward()")))'
    uint256 private constant _INVALID_REWARD_SELECTOR = 0x28829e82;

    /// @dev 'bytes4(keccak256(bytes("InvalidArray()")))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256(bytes("RewardTooLarge()")))'
    uint256 private constant _REWARD_TOO_LARGE_SELECTOR = 0x71009bf7;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a user is rewarded for his listen
    event RewardOnContent(
        address indexed user, ContentId indexed contentId, uint256 baseUserReward, uint256 earningFactor
    );

    /// @dev 'keccak256(bytes("RewardOnContent(address,uint256,uint256,uint256"))'
    uint256 private constant _REWARD_ON_CONTENT_EVENT_SELECTOR =
        0x6396a2d965d9d843b0159912a8413f069bcce1830e320cd0b6cd5dc03d11eddf;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev factor user to compute the number of token to generate (on 1e18 decimals)
    uint256 private tokenGenerationFactor;

    /// @dev The total frak minted for reward
    uint256 private totalFrakMinted;

    /// @dev Access our internal tokens
    FraktionTokens private fraktionTokens;

    /// @dev Access our FRK token
    /// @notice WARN This var is now unused, and so, this slot can be reused for other things
    IFrakToken private frakToken;

    /// @dev Access our referral system
    IReferralPool private referralPool;

    /// @dev Access our content pool
    IContentPool private contentPool;

    /// @dev Address of the frak labs wallet
    address private frakLabsWallet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address frkTokenAddr,
        address fraktionTokensAddr,
        address contentPoolAddr,
        address referralAddr,
        address foundationAddr
    )
        external
        initializer
    {
        if (
            frkTokenAddr == address(0) || fraktionTokensAddr == address(0) || contentPoolAddr == address(0)
                || referralAddr == address(0) || foundationAddr == address(0)
        ) revert InvalidAddress();

        // Only for v1 deployment
        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(frkTokenAddr);

        fraktionTokens = FraktionTokens(fraktionTokensAddr);
        frakToken = IFrakToken(frkTokenAddr);
        contentPool = IContentPool(contentPoolAddr);
        referralPool = IReferralPool(referralAddr);

        frakLabsWallet = foundationAddr;

        // Default TPU
        tokenGenerationFactor = 1 ether;

        // Grant the rewarder role to the contract deployer
        _grantRole(FrakRoles.REWARDER, msg.sender);
        _grantRole(FrakRoles.BADGE_UPDATER, msg.sender);
    }

    /// @dev Reinitialize the contract with the new frak labs address
    function updateFeeReceiver(address newFrakLabsAddress) external reinitializer(2) {
        frakLabsWallet = newFrakLabsAddress;
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Compute the reward for a `listener`, given the `contentType`, `contentIds` and `listenCounts`, and pay him
    /// and the owner
    function payUser(
        address listener,
        uint256 contentType,
        ContentId[] calldata contentIds,
        uint256[] calldata listenCounts
    )
        external
        payable
        onlyRole(FrakRoles.REWARDER)
    {
        // Ensure we got valid data
        assembly {
            if iszero(listener) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            if or(iszero(eq(contentIds.length, listenCounts.length)), gt(contentIds.length, MAX_BATCH_AMOUNT)) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Get the data we will need in this level
        RewardAccounter memory rewardsAccounter = RewardAccounter(0, 0, 0);

        // Get all the payed fraktion types
        uint256 rewardForContentType = baseRewardForContentType(contentType);

        // Iterate over each content the user listened
        uint256 length = contentIds.length;
        for (uint256 i; i < length;) {
            computeRewardForContent(contentIds[i], listenCounts[i], rewardForContentType, listener, rewardsAccounter);

            // Finally, increase the counter
            unchecked {
                ++i;
            }
        }
        // Compute the total amount to mint, and ensure we don't exceed our cap
        unchecked {
            // Apply the user badge
            rewardsAccounter.applyUserBadge(getListenerBadge(listener));

            // Compute the new total frk minted for reward
            uint256 newTotalMint = totalFrakMinted + rewardsAccounter.getTotal();

            // Ensure we don't go past the mint cap
            if (newTotalMint > REWARD_MINT_CAP) {
                revert RewardTooLarge();
            }

            // Increase our total frak minted
            totalFrakMinted = newTotalMint;
        }

        // Register the amount for listener
        _addFoundsUnchecked(listener, rewardsAccounter.user);

        // If we got reward for the pool, transfer them
        if (rewardsAccounter.content > 0) {
            token.safeTransfer(address(contentPool), rewardsAccounter.content);
        }
        /*if (rewardsAccounter.referral > 0) {
            token.safeTransfer(address(referralPool), rewardsAccounter.referral);
        }*/
    }

    /// @dev Withdraw the pending founds of the caller
    function withdrawFounds() external override {
        _withdrawWithFee(msg.sender, FEE_PERCENT, frakLabsWallet);
    }

    /// @dev Withdraw the pending founds of `user`
    function withdrawFounds(address user) external override {
        _withdrawWithFee(user, FEE_PERCENT, frakLabsWallet);
    }

    /// @dev Update the token generation factor to 'newTpu'
    function updateTpu(uint256 newTpu) external onlyRole(FrakRoles.ADMIN) {
        tokenGenerationFactor = newTpu;
    }

    /// @dev Update the 'contentId' 'badge'
    function updateContentBadge(
        ContentId contentId,
        uint256 badge
    )
        external
        override
        onlyRole(FrakRoles.BADGE_UPDATER)
    {
        _updateContentBadge(contentId, badge);
    }

    /// @dev Update the 'listener' 'badge'
    function updateListenerBadge(address listener, uint256 badge) external override onlyRole(FrakRoles.BADGE_UPDATER) {
        _updateListenerBadge(listener, badge);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the current TPU
    function getTpu() external view returns (uint256) {
        return tokenGenerationFactor;
    }

    /// @dev Get the current number of FRK minted
    function getFrkMinted() external view returns (uint256) {
        return totalFrakMinted;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Compute the reward of the given content
    /// @param contentId The id of the content
    /// @param listenCount The number of listen for the given content
    /// @param rewardForContentType The base reward for the given content type
    /// @param listener The listener address
    /// @param rewardsAccounter The current total rewards in memory accounting (that will be updated)
    function computeRewardForContent(
        ContentId contentId,
        uint256 listenCount,
        uint256 rewardForContentType,
        address listener,
        RewardAccounter memory rewardsAccounter
    )
        private
    {
        // Ensure we don't exceed the max ccu / content
        assembly {
            if gt(listenCount, MAX_CCU_PER_CONTENT) {
                mstore(0x00, _INVALID_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Boolean used to know if the user have one paied fraktion
        (uint256 earningFactor, bool hasOnePaidFraktion) = earningFactorForListener(listener, contentId);

        // Get the content badge
        uint256 contentBadge = getContentBadge(contentId);

        uint256 ownerReward;
        uint256 contentPoolReward;
        assembly {
            // Compute the total reward
            // Div by 1e18 since earning factor and token generation factor are on 1e18
            let totalReward :=
                div(mul(mul(listenCount, earningFactor), sload(tokenGenerationFactor.slot)), 1000000000000000000)
            totalReward :=
                div(
                    mul(mul(totalReward, contentBadge), rewardForContentType), mul(1000000000000000000, 1000000000000000000)
                )

            // Exit directly if we got no reward
            if iszero(totalReward) { return(0, 0) }
            // Revert if the reward is too large
            if gt(totalReward, SINGLE_REWARD_CAP) {
                mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                revert(0x1c, 0x04)
            }

            // User reward at 35%
            let userReward := div(mul(totalReward, 35), 100)
            mstore(rewardsAccounter, add(mload(rewardsAccounter), userReward))

            // Check if the user has got paid fraktion
            switch hasOnePaidFraktion
            case 0 {
                // No paid fraktion
                ownerReward := sub(totalReward, userReward)
            }
            default {
                // Have paid fraktion
                contentPoolReward := div(totalReward, 10)
                ownerReward := sub(sub(totalReward, userReward), contentPoolReward)

                // Store the content pool reward
                mstore(add(rewardsAccounter, 0x40), add(mload(add(rewardsAccounter, 0x40)), contentPoolReward))
            }

            // Store the owner reward in memory
            mstore(add(rewardsAccounter, 0x20), add(mload(add(rewardsAccounter, 0x20)), ownerReward))

            // Emit the reward on content event's
            mstore(0, userReward)
            mstore(0x20, earningFactor)
            log3(0, 0x40, _REWARD_ON_CONTENT_EVENT_SELECTOR, listener, contentId)
        }

        // Emit the user reward event, to compute the total amount earned for the given content
        // emit RewardOnContent(listener, contentId, userReward, earningFactor, listenCount);

        if (contentPoolReward > 0) {
            contentPool.addReward(contentId, contentPoolReward);
        }

        // Save the amount for the owner
        address owner = fraktionTokens.ownerOf(contentId);
        // Ensure it's not zero
        assembly {
            if iszero(owner) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _addFoundsUnchecked(owner, ownerReward);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal view functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Compute the earning factor for the given listener
    /// @param listener The listener address
    /// @param contentId The content id
    function earningFactorForListener(
        address listener,
        ContentId contentId
    )
        private
        view
        returns (uint256 earningFactor, bool hasOnePaidFraktion)
    {
        // Build the ids for eachs fraktion that can generate reward, and get the user balance for each one if this
        // fraktions
        FraktionId[] memory fraktionIds = contentId.payableFraktionIds();
        uint256[] memory tokenBalances = fraktionTokens.balanceOfIdsBatch(listener, fraktionIds);

        assembly {
            // Init our earning factor to a single free fraktion (more isn't taken in account) - 0.01 eth
            earningFactor := 10000000000000000

            // Load the offset for each one of our storage pointer
            let currOffset := 0x20
            let offsetEnd := add(0x20, shl(0x05, mload(fraktionIds)))

            // Infinite loop
            for { } 1 { } {
                // Get balance and fraktion type
                let tokenBalance := mload(add(tokenBalances, currOffset))
                let fraktionType := and(mload(add(fraktionIds, currOffset)), 0xF)

                // Update the one paid fraktion value
                if not(hasOnePaidFraktion) {
                    let isPayedFraktion := and(gt(fraktionType, 2), lt(fraktionType, 7))
                    hasOnePaidFraktion := and(isPayedFraktion, gt(tokenBalance, 0))
                }

                // Get base reward for the fraktion type (only payed one, since free is handled on init of the var)
                switch fraktionType
                // common - 0.1
                case 3 { earningFactor := add(mul(100000000000000000, tokenBalance), earningFactor) }
                // premium - 0.5
                case 4 { earningFactor := add(mul(500000000000000000, tokenBalance), earningFactor) }
                // gold - 1
                case 5 { earningFactor := add(mul(1000000000000000000, tokenBalance), earningFactor) }
                // diamond - 2
                case 6 { earningFactor := add(mul(2000000000000000000, tokenBalance), earningFactor) }

                // Increase our offset's
                currOffset := add(currOffset, 0x20)

                // Exit if we reached the end
                if iszero(lt(currOffset, offsetEnd)) { break }
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal pure functions                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Compute the base reward for the given `contentType`
    function baseRewardForContentType(uint256 contentType) private pure returns (uint256 reward) {
        if (contentType == CONTENT_TYPE_VIDEO) {
            reward = 2 ether;
        } else if (contentType == CONTENT_TYPE_PODCAST) {
            reward = 1 ether;
        } else if (contentType == CONTENT_TYPE_MUSIC) {
            reward = 0.2 ether;
        } else if (contentType == CONTENT_TYPE_STREAMING) {
            reward = 1 ether;
        } else {
            reward = 0;
        }
    }
}
