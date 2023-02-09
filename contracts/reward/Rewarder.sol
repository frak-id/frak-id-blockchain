// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {IRewarder} from "./IRewarder.sol";
import {ContentBadges} from "./badges/ContentBadges.sol";
import {ListenerBadges} from "./badges/ListenerBadges.sol";
import {ContentPool} from "./pool/ContentPool.sol";
import {ReferralPool} from "./pool/ReferralPool.sol";
import {FrakMath} from "../utils/FrakMath.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {FraktionTokens} from "../tokens/FraktionTokens.sol";
import {FrakToken} from "../tokens/FrakTokenL2.sol";
import {FrakAccessControlUpgradeable} from "../utils/FrakAccessControlUpgradeable.sol";
import {InvalidAddress, InvalidArray, RewardTooLarge} from "../utils/FrakErrors.sol";
import {PushPullReward} from "../utils/PushPullReward.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

// Error throwned by this contract
error TooMuchCcu();
error InvalidReward();

/**
 * @dev Represent our rewarder contract
 */
/// @custom:security-contact contact@frak.id
contract Rewarder is IRewarder, FrakAccessControlUpgradeable, ContentBadges, ListenerBadges, PushPullReward {
    using SafeERC20Upgradeable for FrakToken;
    using FrakMath for uint256;

    // The cap of frak token we can mint for the reward
    uint256 public constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint256 private constant SINGLE_REWARD_CAP = 50_000 ether;
    uint256 private constant DIRECT_REWARD_CAP = 53 ether;

    // Maximum data we can treat in a batch manner
    uint256 private constant MAX_BATCH_AMOUNT = 20;
    uint256 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

    // Maximum data we can treat in a batch manner
    uint256 private constant CONTENT_TYPE_VIDEO = 1;
    uint256 private constant CONTENT_TYPE_PODCAST = 2;
    uint256 private constant CONTENT_TYPE_MUSIC = 3;
    uint256 private constant CONTENT_TYPE_STREAMING = 4;

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("InvalidReward()")))'
    uint256 private constant _INVALID_REWARD_SELECTOR = 0x28829e82;

    /// @dev 'bytes4(keccak256(bytes("InvalidArray()")))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256(bytes("RewardTooLarge()")))'
    uint256 private constant _REWARD_TOO_LARGE_SELECTOR = 0x71009bf7;

    /// @dev Event emitted when a user is rewarded for his listen
    event RewardOnContent(
        address indexed user, uint256 indexed contentId, uint256 baseUserReward, uint256 earningFactor, uint16 ccuCount
    );

    /// @dev 'keccak256(bytes("RewardOnContent(address,uint256,uint256,uint256,uint16"))'
    uint256 private constant _REWARD_ON_CONTENT_EVENT_SELECTOR =
        0x660494162a7aab2356c74a0a63c109a0a2ac6ac9d3b95415756bac61af417ecb;

    /**
     * @notice factor user to compute the number of token to generate (on 1e18 decimals)
     */
    uint256 public tokenGenerationFactor;

    /**
     * @notice The total frak minted for reward
     */
    uint256 public totalFrakMinted;

    /**
     * @dev Access our internal tokens
     */
    FraktionTokens private fraktionTokens;

    /**
     * @dev Access our token
     */
    FrakToken private frakToken;

    /**
     * @dev Access our referral system
     */
    ReferralPool private referralPool;

    /**
     * @dev Access our content pool
     */
    ContentPool private contentPool;

    /**
     * @dev Address of the foundation wallet
     */
    address private foundationWallet;

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
    ) external initializer {
        if (
            frkTokenAddr == address(0) || fraktionTokensAddr == address(0) || contentPoolAddr == address(0)
                || referralAddr == address(0) || foundationAddr == address(0)
        ) revert InvalidAddress();

        // Only for v1 deployment
        __FrakAccessControlUpgradeable_init();
        __PushPullReward_init(frkTokenAddr);

        fraktionTokens = FraktionTokens(fraktionTokensAddr);
        frakToken = FrakToken(frkTokenAddr);
        contentPool = ContentPool(contentPoolAddr);
        referralPool = ReferralPool(referralAddr);

        foundationWallet = foundationAddr;

        // Default TPU
        tokenGenerationFactor = 1 ether;

        // Grant the rewarder role to the contract deployer
        _grantRole(FrakRoles.REWARDER, msg.sender);
        _grantRole(FrakRoles.BADGE_UPDATER, msg.sender);
    }

    struct TotalRewards {
        uint256 user;
        uint256 owners;
        uint256 referral;
        uint256 content;
    }

    /**
     * @notice Directly pay a user for the given frk amount (used for offchain to onchain wallet migration)
     */
    function payUserDirectly(address listener, uint256 amount)
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        whenNotPaused
    {
        assembly {
            // Ensure the param are valid and not too much
            if iszero(listener) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            if or(iszero(amount), gt(amount, DIRECT_REWARD_CAP)) {
                mstore(0x00, _INVALID_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Compute the new total amount
            let newTotalAmount := add(amount, sload(totalFrakMinted.slot))
            // Ensure it's good
            if gt(newTotalAmount, REWARD_MINT_CAP) {
                mstore(0x00, _INVALID_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Increase our total frak minted
            sstore(totalFrakMinted.slot, newTotalAmount)
        }

        // Mint the reward for the user
        frakToken.safeTransfer(listener, amount);
    }

    /**
     * @notice Directly pay all the creator for the given frk amount (used for offchain reward created by the user, that is sent to the creator)
     */
    function payCreatorDirectlyBatch(uint256[] calldata contentIds, uint256[] calldata amounts)
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        whenNotPaused
    {
        assembly {
            // Ensure we got valid data
            if or(iszero(eq(contentIds.length, amounts.length)), gt(contentIds.length, MAX_BATCH_AMOUNT)) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Then, for each content contentIds
        for (uint256 i; i < contentIds.length;) {
            // TODO : Do that in assembly (all the for loops)
            // TODO : copy calldata to memory for iteration ? calldatacopy(...)
            uint256 amount = amounts[i];
            assembly {
                // Ensure the reward is valid
                if or(iszero(amount), gt(amount, DIRECT_REWARD_CAP)) {
                    mstore(0x00, _INVALID_REWARD_SELECTOR)
                    revert(0x1c, 0x04)
                }
                // Compute the new total amount
                let newTotalAmount := add(amount, sload(totalFrakMinted.slot))
                // Ensure it's good
                if gt(newTotalAmount, REWARD_MINT_CAP) {
                    mstore(0x00, _INVALID_REWARD_SELECTOR)
                    revert(0x1c, 0x04)
                }
                // Increase our total frak minted
                sstore(totalFrakMinted.slot, newTotalAmount)
            }
            // Get the creator address
            address owner = fraktionTokens.ownerOf(contentIds[i]);
            // Ensure it's not zero
            assembly {
                if iszero(owner) {
                    mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                    revert(0x1c, 0x04)
                }
            }
            // Add this founds
            _addFoundsUnchecked(owner, amounts[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Compute the reward for a user, given the content and listens, and pay him and the owner
     */
    function payUser(address listener, uint8 contentType, uint256[] calldata contentIds, uint16[] calldata listenCounts)
        external
        payable
        onlyRole(FrakRoles.REWARDER)
        whenNotPaused
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
        TotalRewards memory totalRewards = TotalRewards(0, 0, 0, 0);

        // Get all the payed fraktion types
        uint256[] memory fraktionTypes = FrakMath.payableTokenTypes();
        uint256 rewardForContentType = baseRewardForContentType(contentType);

        // Iterate over each content the user listened
        for (uint256 i; i < contentIds.length;) {
            computeRewardForContent(
                contentIds[i], listenCounts[i], rewardForContentType, listener, fraktionTypes, totalRewards
            );

            // Finally, increase the counter
            unchecked {
                ++i;
            }
        }

        // Then outside of our loop find the user badge
        uint256 listenerBadge = getListenerBadge(listener);

        // Update the total mint for user with his listener badges
        totalRewards.user = wadMulDivDown(totalRewards.user, listenerBadge);

        // Register the amount for listener
        _addFoundsUnchecked(listener, totalRewards.user);

        // Compute the total amount to mint, and ensure we don't exceed our cap
        assembly {
            // Compute the total to be minted
            let userAndOwner := add(mload(totalRewards), mload(add(totalRewards, 0x20)))
            let referralAndContent := add(mload(add(totalRewards, 0x40)), mload(add(totalRewards, 0x60)))
            let totalMint := add(userAndOwner, referralAndContent)

            // Compute the new total amount
            let newTotalAmount := add(totalMint, sload(totalFrakMinted.slot))
            // Ensure it's good
            if gt(newTotalAmount, REWARD_MINT_CAP) {
                mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Increase our total frak minted
            sstore(totalFrakMinted.slot, newTotalAmount)
        }

        // If we got reward for the pool, transfer them
        if (totalRewards.content > 0) {
            frakToken.safeTransfer(address(contentPool), totalRewards.content);
        }
        if (totalRewards.referral > 0) {
            frakToken.safeTransfer(address(referralPool), totalRewards.referral);
        }
    }

    /**
     * @dev Compute the user and owner reward for the given content
     */
    function computeRewardForContent(
        uint256 contentId,
        uint16 listenCount,
        uint256 rewardForContentType,
        address listener,
        uint256[] memory fraktionTypes,
        TotalRewards memory totalRewards
    ) private {
        // Boolean used to know if the user have one paied fraktion
        (uint256 earningFactor, bool hasOnePaidFraktion) = earningFactorForListener(fraktionTypes, listener, contentId);

        // Get the content badge
        uint256 contentBadge = getContentBadge(contentId);
        // Start our total reward with the earning factor, the listen count, and the TPU's
        uint256 totalReward = wadMulDivDown(listenCount * earningFactor, tokenGenerationFactor);
        // Then apply the content badge and then content type ratio
        totalReward = multiWadMulDivDown(totalReward, contentBadge, rewardForContentType);
        // Ensure the reward isn't too large
        if (totalReward > SINGLE_REWARD_CAP) revert RewardTooLarge();
        else if (totalReward == 0) return;

        uint256 userReward;
        uint256 ownerReward;
        if (hasOnePaidFraktion) {
            // Compute the reward for the content pool and the referral
            uint256 contentPoolReward;
            unchecked {
                // Compute the reward
                userReward = (totalReward * 35) / 100;
                ownerReward = totalReward - userReward;

                // Increment the two amount that won't change after
                totalRewards.user += userReward;

                // Content pool reward at 10%
                contentPoolReward = totalReward / 10;
            }
            // Send the reward to the content ool and referral pool
            contentPool.addReward(contentId, contentPoolReward);

            // Decrease the owner reward by the pool amount used
            unchecked {
                // Decrease the owner reward
                ownerReward -= contentPoolReward;

                // Increase all the total one
                totalRewards.content += contentPoolReward;
                totalRewards.owners += ownerReward;
            }
        } else {
            // Increase the user and owners amount to be minted
            unchecked {
                // Compute the rewards
                userReward = (totalReward * 35) / 100;
                ownerReward = totalReward - userReward;

                // Increment the totals rewards
                totalRewards.user += userReward;
                totalRewards.owners += ownerReward;
            }
        }

        // Emit the user reward event, to compute the total amount earned for the given content
        emit RewardOnContent(listener, contentId, userReward, earningFactor, listenCount);

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

    /**
     * @dev Compute the earning factor for a listener on a given content
     */
    function earningFactorForListener(uint256[] memory fraktionTypes, address listener, uint256 contentId)
        private
        view
        returns (uint256 earningFactor, bool hasOnePaidFraktion)
    {
        // Build the ids for eachs fraktion that can generate reward, and get the user balance for each one if this fraktions
        uint256[] memory fraktionIds = contentId.buildSnftIds(fraktionTypes);
        uint256[] memory tokenBalances = fraktionTokens.balanceOfIdsBatch(listener, fraktionIds);

        // default value to free fraktion
        earningFactor = baseRewardForTokenType(FrakMath.TOKEN_TYPE_FREE_MASK);
        hasOnePaidFraktion = false;

        assembly {
            // Get the length
            let length := mload(tokenBalances)

            // Load the offset for each one of our storage pointer
            let tokenBalancesOffset := add(tokenBalances, 0x20)
            let fraktionTypeOffset := add(fraktionTypes, 0x20)

            // Iterate over each one of them
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                // Get balance and fraktion type
                let tokenBalance := mload(add(tokenBalancesOffset, mul(0x20, i)))
                let fraktionType := mload(add(fraktionTypeOffset, mul(0x20, i)))

                // Update the one paid fraktion value
                if not(hasOnePaidFraktion) {
                    let isPayedFraktion := and(gt(fraktionType, 2), lt(fraktionType, 7))
                    hasOnePaidFraktion := and(isPayedFraktion, gt(tokenBalance, 0))
                }

                // Get base reward for the fraktion type
                let addedReward := 0
                switch fraktionType
                case 2 { addedReward := mul(10000000000000000, tokenBalance) } // free - 0.01
                case 3 { addedReward := mul(100000000000000000, tokenBalance) } // common - 0.1
                case 4 { addedReward := mul(500000000000000000, tokenBalance) } // premium - 0.5
                case 5 { addedReward := mul(1000000000000000000, tokenBalance) } // gold - 1
                case 6 { addedReward := mul(2000000000000000000, tokenBalance) } // diamond - 2 
                default {}

                // Update the earning factor if balance are present
                earningFactor := add(earningFactor, addedReward)
            }
        }

        // Iterate over each balance to compute the earning factor
        /*for (uint256 balanceIndex; balanceIndex < tokenBalances.length;) {
            uint256 balance = tokenBalances[balanceIndex];
            // Check if that was a paid fraktion or not
            hasOnePaidFraktion = hasOnePaidFraktion || fraktionTypes[balanceIndex].isPayedTokenToken() && balance > 0);
            // Increase the earning factor
            unchecked {
                // On 1e18 decimals
                earningFactor += balance * baseRewardForTokenType(fraktionTypes[balanceIndex]);
                ++balanceIndex;
            }
        }*/
    }

    /// @dev Use multi wad div down for multi precision when multiple value of 1 eth
    function wadMulDivDown(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // Divide x * y by the 1e18 (decimals).
            z := div(mul(x, y), 1000000000000000000)
        }
    }

    /// @dev Use multi wad div down for multi precision when multiple value of 1 eth
    function multiWadMulDivDown(uint256 x, uint256 y, uint256 z) internal pure returns (uint256 r) {
        assembly {
            // Divide x * y by the 1e18 (decimals).
            r := div(mul(mul(x, y), z), mul(1000000000000000000, 1000000000000000000))
        }
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function baseRewardForTokenType(uint256 tokenType) private pure returns (uint256 reward) {
        if (tokenType == FrakMath.TOKEN_TYPE_FREE_MASK) {
            // 0.01 FRK
            reward = 0.01 ether;
        } else if (tokenType == FrakMath.TOKEN_TYPE_COMMON_MASK) {
            // 0.1 FRK
            reward = 0.1 ether;
        } else if (tokenType == FrakMath.TOKEN_TYPE_PREMIUM_MASK) {
            // 0.5 FRK
            reward = 0.5 ether;
        } else if (tokenType == FrakMath.TOKEN_TYPE_GOLD_MASK) {
            // 1 FRK
            reward = 1 ether;
        } else if (tokenType == FrakMath.TOKEN_TYPE_DIAMOND_MASK) {
            // 2 FRK
            reward = 2 ether;
        } else {
            reward = 0;
        }
    }

    /**
     * @dev Get the base reward to the given content type
     */
    function baseRewardForContentType(uint8 contentType) private pure returns (uint256 reward) {
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

    /**
     * @dev Update the token generation factor
     */
    function updateTpu(uint256 newTpu) external onlyRole(FrakRoles.ADMIN) {
        tokenGenerationFactor = newTpu;
    }

    /**
     * @dev Withdraw my pending founds
     */
    function withdrawFounds() external virtual override whenNotPaused {
        _withdrawWithFee(msg.sender, 2, foundationWallet);
    }

    /**
     * @dev Withdraw the pending founds for a user
     */
    function withdrawFounds(address user) external virtual override onlyRole(FrakRoles.ADMIN) whenNotPaused {
        _withdrawWithFee(user, 2, foundationWallet);
    }

    /**
     * @dev Update the content badge
     */
    function updateContentBadge(uint256 contentId, uint256 badge)
        external
        override
        onlyRole(FrakRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateContentBadge(contentId, badge);
    }

    /**
     * @notice Update the listener badge
     */
    function updateListenerBadge(address listener, uint256 badge)
        external
        override
        onlyRole(FrakRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateListenerBadge(listener, badge);
    }
}
