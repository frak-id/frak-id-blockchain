// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IRewarder.sol";
import "./badges/ContentBadges.sol";
import "./badges/ListenerBadges.sol";
import "./pool/ContentPool.sol";
import "./pool/ReferralPool.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/PushPullReward.sol";

// Error throwned by this contract
error TooMuchCcu();
error InvalidReward();

/**
 * @dev Represent our rewarder contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Rewarder is IRewarder, SybelAccessControlUpgradeable, ContentBadges, ListenerBadges, PushPullReward {
    using SybelMath for uint256;

    // The cap of frak token we can mint for the reward
    uint256 public constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint256 private constant SINGLE_REWARD_CAP = 1_000_000 ether;

    // Maximum data we can treat in a batch manner
    uint256 private constant MAX_BATCH_AMOUNT = 20;
    uint256 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

    // Maximum data we can treat in a batch manner
    uint256 private constant CONTENT_TYPE_VIDEO = 1;
    uint256 private constant CONTENT_TYPE_PODCAST = 2;
    uint256 private constant CONTENT_TYPE_MUSIC = 3;
    uint256 private constant CONTENT_TYPE_STREAMING = 4;

    /**
     * @dev factor user to compute the number of token to generate (on 1e18 decimals)
     */
    uint256 public tokenGenerationFactor;

    /**
     * @dev The total frak minted for reward
     */
    uint256 public totalFrakMinted;

    /**
     * @dev Access our internal tokens
     */
    SybelInternalTokens private sybelInternalTokens;

    /**
     * @dev Access our token
     */
    SybelToken private sybelToken;

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

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserRewarded(
        address indexed user,
        uint256[] contentIds,
        uint16[] listenCount,
        uint256 userReward,
        uint256 poolRewards
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address syblTokenAddr,
        address internalTokenAddr,
        address contentPoolAddr,
        address referralAddr,
        address foundationAddr
    ) external initializer {
        // Only for v1 deployment
        __SybelAccessControlUpgradeable_init();
        __PushPullReward_init(syblTokenAddr);

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(syblTokenAddr);
        contentPool = ContentPool(contentPoolAddr);
        referralPool = ReferralPool(referralAddr);

        foundationWallet = foundationAddr;

        // Default TPU
        tokenGenerationFactor = 1 ether;

        // Grant the rewarder role to the contract deployer
        _grantRole(SybelRoles.REWARDER, msg.sender);
        _grantRole(SybelRoles.BADGE_UPDATER, msg.sender);
    }

    struct TotalRewards {
        uint256 user;
        uint256 owners;
        uint256 referral;
        uint256 content;
    }

    /**
     * @dev Directly pay a user (or an owner) for the given frk amount
     */
    function payUserDirectly(address listener, uint256 amount) external onlyRole(SybelRoles.REWARDER) whenNotPaused {
        // Ensure the param are valid and not too much
        if (listener == address(0)) revert InvalidAddress();
        if (amount > SINGLE_REWARD_CAP || amount == 0 || amount + totalFrakMinted > REWARD_MINT_CAP)
            revert InvalidReward();

        // Increase our total frak minted
        totalFrakMinted += amount;

        // Mint the reward for the user
        sybelToken.mint(listener, amount);
    }

    /**
     * @dev Compute the reward for a user, given the content and listens, and pay him and the owner
     */
    function payUser(
        address listener,
        uint8 contentType,
        uint256[] calldata contentIds,
        uint16[] calldata listenCounts
    ) external onlyRole(SybelRoles.REWARDER) whenNotPaused {
        // Ensure we got valid data
        if (contentIds.length != listenCounts.length || contentIds.length > MAX_BATCH_AMOUNT) revert InvalidArray();

        // Get the data we will need in this level
        TotalRewards memory totalRewards = TotalRewards(0, 0, 0, 0);

        // Get all the payed fraktion types
        uint8[] memory fraktionTypes = SybelMath.payableTokenTypes();
        uint256 rewardForContentType = baseRewardForContentType(contentType);

        // Iterate over each content the user listened
        for (uint256 i; i < contentIds.length; ) {
            computeRewardForContent(
                contentIds[i],
                listenCounts[i],
                rewardForContentType,
                listener,
                fraktionTypes,
                totalRewards
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
        unchecked {
            uint256 totalMint = totalRewards.user + totalRewards.owners + totalRewards.content + totalRewards.referral;
            if (totalMint + totalFrakMinted > REWARD_MINT_CAP) revert InvalidReward();
            totalFrakMinted += totalMint;
        }
        emit UserRewarded(
            listener,
            contentIds,
            listenCounts,
            totalRewards.user,
            totalRewards.content + totalRewards.referral
        );

        // If we got reward for the pool, mint them
        if (totalRewards.content > 0 || totalRewards.referral > 0) {
            sybelToken.mint(address(this), totalRewards.user + totalRewards.owners);
            sybelToken.mint(address(contentPool), totalRewards.content);
            sybelToken.mint(address(referralPool), totalRewards.referral);
        } else {
            // Otherwise, only mint for this contract
            sybelToken.mint(address(this), totalRewards.user + totalRewards.owners);
        }
    }

    function computeRewardForContent(
        uint256 contentId,
        uint16 listenCount,
        uint256 rewardForContentType,
        address listener,
        uint8[] memory fraktionTypes,
        TotalRewards memory totalRewards
    ) private {
        // TODO : Also ensure this podcast is minted
        // Ensure we don't exceed the max ccu / content
        if (listenCount > MAX_CCU_PER_CONTENT) revert TooMuchCcu();

        // Build the ids for eachs fraktion that can generate reward, and get the user balance for each one if this fraktions
        uint256[] memory fraktionIds = SybelMath.buildSnftIds(contentId, fraktionTypes);
        uint256[] memory tokenBalances = sybelInternalTokens.balanceOfIdsBatch(listener, fraktionIds);

        // Boolean used to know if the user have one paied fraktion
        bool hasOnePayedFraktion;

        // The content earning factor of the user
        uint256 earningFactor;

        // Iterate over each balance to compute the earning factor
        for (uint256 balanceIndex; balanceIndex < tokenBalances.length; ) {
            uint256 balance = tokenBalances[balanceIndex];
            // Check if that was a paid fraktion or not
            hasOnePayedFraktion =
                hasOnePayedFraktion ||
                (SybelMath.isPayedTokenToken(fraktionTypes[balanceIndex]) && balance > 0);
            // Increase the earning factor
            unchecked {
                earningFactor += balance * baseRewardForTokenType(fraktionTypes[balanceIndex]);
                // On 1e18 decimals
                ++balanceIndex;
            }
        }

        // If the earning factor is at 0, just mint a free fraktion and increase it
        if (earningFactor == 0) {
            sybelInternalTokens.mint(listener, SybelMath.buildFreeNftId(contentId), 1);
            earningFactor = baseRewardForTokenType(SybelMath.TOKEN_TYPE_FREE_MASK);
        }

        // Get the content badge
        uint256 contentBadge = getContentBadge(contentId);
        // Start our total reward with the earning factor, the listen count, and the TPU's
        uint256 totalReward = multiWadMulDivDown(listenCount, earningFactor, tokenGenerationFactor);
        // Then apply the content badge and then content type ratio
        totalReward *= multiWadMulDivDown(totalReward, contentBadge, rewardForContentType);
        // Same here should use WaD multiplier
        // Ensure the reward isn't too large
        if (totalReward > SINGLE_REWARD_CAP) revert InvalidReward();
        else if (totalReward == 0) return;

        uint256 userReward;
        uint256 ownerReward;
        if (hasOnePayedFraktion) {
            // Compute the reward for the content pool and the referral
            uint256 contentPoolReward;
            uint256 baseReferralReward;
            unchecked {
                // Compute the rewards
                userReward = (totalReward * 35) / 100;
                ownerReward = totalReward - userReward;

                // Increment the two amount that won't change after
                totalRewards.user += userReward;

                contentPoolReward = totalReward / 10;
                // Content pool reward at 10%
                baseReferralReward = (totalReward * 3) / 50;
                // Referral pool base at 6%
            }
            // Send the reward to the content ool and referral pool
            contentPool.addReward(contentId, contentPoolReward);
            uint256 referralPoolReward = referralPool.payAllReferer(contentId, listener, baseReferralReward);

            // Decrease the owner reward by the pool amount used
            unchecked {
                // Decrease the owner reward
                ownerReward -= contentPoolReward - referralPoolReward;

                // Increase all the total one
                totalRewards.content += contentPoolReward;
                totalRewards.referral += referralPoolReward;
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
        // Save the amount for the owner
        address owner = sybelInternalTokens.ownerOf(contentId);
        _addFoundsUnchecked(owner, ownerReward);
    }

    function wadMulDivDown(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // Divide x * y by the 1e18 (decimals).
            z := div(mul(x, y), 1000000000000000000)
        }
    }

    /// Use multi wad div down for multi precision when multiple value of 1 eth
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
    function baseRewardForTokenType(uint8 tokenType) private pure returns (uint256 reward) {
        if (tokenType == SybelMath.TOKEN_TYPE_FREE_MASK) {
            // 0.01 FRK
            reward = 0.01 ether;
        } else if (tokenType == SybelMath.TOKEN_TYPE_COMMON_MASK) {
            // 0.1 FRK
            reward = 0.1 ether;
        } else if (tokenType == SybelMath.TOKEN_TYPE_PREMIUM_MASK) {
            // 0.5 FRK
            reward = 0.5 ether;
        } else if (tokenType == SybelMath.TOKEN_TYPE_GOLD_MASK) {
            // 1 FRK
            reward = 1 ether;
        } else if (tokenType == SybelMath.TOKEN_TYPE_DIAMOND_MASK) {
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
    function updateTpu(uint256 newTpu) external onlyRole(SybelRoles.ADMIN) {
        tokenGenerationFactor = newTpu;
    }

    function withdrawFounds() external virtual override whenNotPaused {
        _withdraw(msg.sender);
    }

    function withdrawFounds(address user) external virtual override onlyRole(SybelRoles.ADMIN) whenNotPaused {
        _withdrawWithFee(user, 2, foundationWallet);
    }

    function updateContentBadge(
        uint256 contentId,
        uint256 badge
    ) external override onlyRole(SybelRoles.BADGE_UPDATER) whenNotPaused {
        _updateContentBadge(contentId, badge);
    }

    function updateListenerBadge(
        address listener,
        uint256 badge
    ) external override onlyRole(SybelRoles.BADGE_UPDATER) whenNotPaused {
        _updateListenerBadge(listener, badge);
    }

    function getTpu() external view returns (uint256) {
        return tokenGenerationFactor;
    }
}
