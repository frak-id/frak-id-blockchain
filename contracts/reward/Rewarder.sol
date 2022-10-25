// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

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

/**
 * @dev Represent our rewarder contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Rewarder is IRewarder, SybelAccessControlUpgradeable, ContentBadges, ListenerBadges, PushPullReward {
    // The cap of frak token we can mint for the reward
    uint96 public constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint96 private constant SINGLE_REWARD_CAP = 1_000_000 ether;

    // Maximum data we can treat in a batch manner
    uint8 private constant MAX_BATCH_AMOUNT = 20;
    uint16 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

    /**
     * @dev Access our internal tokens
     */
    SybelInternalTokens private sybelInternalTokens;

    /**
     * @dev Access our token
     */
    /// @custom:oz-renamed-from tokenSybelEcosystem
    SybelToken private sybelToken;

    /**
     * @dev Access our referral system
     */
    ReferralPool private referral;

    /**
     * @dev Access our content pool
     */
    ContentPool private contentPool;

    /**
     * @dev factor user to compute the number of token to generate (on 1e18 decimals)
     */
    uint256 public tokenGenerationFactor;

    /**
     * @dev The total frak minted for reward
     */
    uint96 public totalFrakMinted;

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserRewarded(
        address indexed user,
        uint256[] contentIds,
        uint16[] listenCount,
        uint96 userReward,
        uint96 poolRewards
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address syblTokenAddr,
        address internalTokenAddr,
        address contentPoolAddr,
        address referralAddr
    ) external initializer {
        // Only for v1 deployment
        __SybelAccessControlUpgradeable_init();
        __PushPullReward_init(syblTokenAddr);

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(syblTokenAddr);
        contentPool = ContentPool(contentPoolAddr);
        referral = ReferralPool(referralAddr);

        // Default TPU
        tokenGenerationFactor = 4.22489708885 ether;

        // Grant the rewarder role to the contract deployer
        _grantRole(SybelRoles.REWARDER, msg.sender);
        _grantRole(SybelRoles.BADGE_UPDATER, msg.sender);
    }

    /**
     * @dev Pay a user for all the listening he have done on different content
     */
    function payUser(
        address listener,
        uint256[] calldata contentIds,
        uint16[] calldata listenCounts
    ) external override onlyRole(SybelRoles.REWARDER) whenNotPaused {
        require(contentIds.length == listenCounts.length, "SYB: invalid array length");
        require(contentIds.length <= MAX_BATCH_AMOUNT, "SYB: array too large");
        // Get our total amopunt to be minted
        uint96 totalAmountToMintForOwnerAndPool = 0;
        uint96 totalAmountToMintForUser = 0;
        // Iterate over each content
        for (uint256 i = 0; i < contentIds.length; ++i) {
            // TODO : Do we need to ensure that the podcast exist ???
            // Ensure we don't exceed the max ccu / content
            require(listenCounts[i] < MAX_CCU_PER_CONTENT, "SYB: too much ccu");
            // Find the balance of the listener for this content
            (
                ListenerBalanceOnContent[] memory balances,
                bool hasAtLeastOneBalance,
                bool hasOnePayedToken
            ) = getListenerBalanceForContent(listener, contentIds[i]);
            // If no balance mint a Standard NFT
            if (!hasAtLeastOneBalance) {
                sybelInternalTokens.mint(listener, SybelMath.buildFreeNftId(contentIds[i]), 1);
                // And then recompute his balance
                (balances, hasAtLeastOneBalance, hasOnePayedToken) = getListenerBalanceForContent(
                    listener,
                    contentIds[i]
                );
            }
            // If he as at least one balance
            if (hasAtLeastOneBalance) {
                ComputeRewardParam memory computeRewardParam = ComputeRewardParam({
                    listener: listener,
                    contentId: contentIds[i],
                    listenCount: listenCounts[i],
                    hasOnePayedToken: hasOnePayedToken,
                    balances: balances
                });
                (uint96 totalContentPool, uint96 totalForUser) = computeContentReward(computeRewardParam);
                totalAmountToMintForOwnerAndPool += totalContentPool;
                totalAmountToMintForUser += totalForUser;
            }
        }
        // Get the listener badge and recompute his reward
        uint64 listenerBadge = getListenerBadge(listener);
        uint96 amountForListener = uint96((uint256(totalAmountToMintForUser) * listenerBadge) / 1 ether);
        // Register the amount for listener
        _addFounds(listener, amountForListener);
        // Compute the total amount to mint
        uint96 totalAmountToMint = amountForListener + totalAmountToMintForOwnerAndPool;
        // Ensure we don't go poast our mint cap
        require(totalAmountToMint + totalFrakMinted <= REWARD_MINT_CAP, "SYB: exceed mint cap");
        require(totalAmountToMint != 0, "SYB: no reward to be given");
        // If good, update our total frak minted and emit the event
        totalFrakMinted += totalAmountToMint;
        emit UserRewarded(listener, contentIds, listenCounts, amountForListener, totalAmountToMintForOwnerAndPool);

        // Once we have iterate over each item, if we got a positive mint amount, mint it
        if (totalAmountToMint > 0) {
            sybelToken.mint(address(this), totalAmountToMint);
        }
    }

    /**
     * @dev Find the balance of the given user on each tokens
     */
    function getListenerBalanceForContent(address listener, uint256 contentId)
        private
        view
        returns (
            ListenerBalanceOnContent[] memory,
            bool hasAtLeastOneBalance,
            bool hasOnePaiedFraktion
        )
    {
        // The different types we will fetch
        uint8[] memory types = SybelMath.payableTokenTypes();
        // Build the ids for eachs types
        uint256[] memory tokenIds = SybelMath.buildSnftIds(contentId, types);
        // Build our initial balance map
        ListenerBalanceOnContent[] memory balances = new ListenerBalanceOnContent[](types.length);
        // Get the balance
        uint256[] memory tokenBalances = sybelInternalTokens.balanceOfIdsBatch(listener, tokenIds);
        // Iterate over each types to find the balances
        for (uint8 i = 0; i < types.length; ++i) {
            // Get the balance and build our balance on content object
            uint256 balance = tokenBalances[i];
            balances[i] = ListenerBalanceOnContent(types[i], tokenBalances[i]);
            // Update our has at least one balance object
            hasAtLeastOneBalance = hasAtLeastOneBalance || balance > 0;
            // Update our has one paid fraktion
            hasOnePaiedFraktion = hasOnePaiedFraktion || (SybelMath.isPayedTokenToken(types[i]) && balance > 0);
        }
        return (balances, hasAtLeastOneBalance, hasOnePaiedFraktion);
    }

    /**
     * Struct used to compute the content reward
     */
    struct ComputeRewardParam {
        address listener;
        uint256 contentId;
        uint16 listenCount;
        bool hasOnePayedToken;
        ListenerBalanceOnContent[] balances;
    }

    /**
     * @dev Mint the reward for the given user, and take in account his balances for the given content
     */
    function computeContentReward(ComputeRewardParam memory param)
        private
        returns (uint96 poolAndOwnerRewardAmount, uint96 userReward)
    {
        // The user have a balance we can continue
        uint256 contentBadge = getContentBadge(param.contentId);
        // Mint each token for each fraction
        uint96 totalReward = 0;
        for (uint8 i = 0; i < param.balances.length; ++i) {
            if (param.balances[i].balance <= 0) {
                // Jump this iteration if the user havn't go any balance of this token types
                continue;
            }
            // Compute the total reward amount
            totalReward += computeUserRewardForFraction(
                param.balances[i].balance,
                param.balances[i].tokenType,
                contentBadge,
                param.listenCount
            );
        }
        // If no reward, directly exit
        if (totalReward == 0) {
            return (0, 0);
        }
        // Ensure the reward isn't too large, and also ensure it fit inside a uint96
        require(totalReward < SINGLE_REWARD_CAP, "SYB: reward too large");
        // Then split the payment for owner and user (TODO : Also referral and content pools)
        userReward = (totalReward * 35) / 100;

        // Compute the initial owner reward
        uint96 ownerReward = totalReward - userReward;
        uint96 poolReward;

        // If the user has one payed token, send it to the different pools
        if (param.hasOnePayedToken) {
            // Send the reward to the content pool, and decrease the owner reward
            uint96 contentPoolReward = (totalReward * 10) / 100;
            poolReward += contentPoolReward;
            contentPool.addReward(param.contentId, poolReward);

            // Compute the reward for the referral
            uint96 baseReferralReward = (totalReward * 6) / 100; // Reward for the referral
            uint96 usedReferralReward = referral.payAllReferer(param.contentId, param.listener, baseReferralReward);
            // Decrease the owner reward
            poolReward += usedReferralReward;
        }

        // Decrease the owner reward by the pool amount used
        ownerReward -= poolReward;
        // Update the global reward
        poolAndOwnerRewardAmount = ownerReward + poolReward;
        // Save the amount for the owner
        address owner = sybelInternalTokens.ownerOf(param.contentId);
        _addFounds(owner, ownerReward);
        // Return our result
        return (poolAndOwnerRewardAmount, userReward);
    }

    /**
     * @dev Compute the user reward for the given fraction
     */
    function computeUserRewardForFraction(
        uint256 balance,
        uint8 tokenType,
        uint256 contentBadge, // Badge on 1e18 decimals
        uint16 consumedContentUnit
    ) private view returns (uint96 reward) {
        // Compute the earning factor
        uint256 earningFactor = balance * baseRewardForTokenType(tokenType); // On 1e18 decimals
        // Compute the badge reward (and divied it by 1e18 since we have 2 value on 1e18 decimals)
        uint256 badgeReward = (contentBadge * earningFactor * consumedContentUnit);
        reward = uint96((badgeReward * tokenGenerationFactor) / (1 ether * 1 ether));
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function baseRewardForTokenType(uint8 tokenType) private pure returns (uint96 reward) {
        if (tokenType == SybelMath.TOKEN_TYPE_FREE_MASK) {
            reward = 0.01 ether; // 0.01 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_COMMON_MASK) {
            reward = 0.1 ether; // 0.1 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_PREMIUM_MASK) {
            reward = 0.5 ether; // 0.5 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_GOLD_MASK) {
            reward = 1 ether; // 1 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_DIAMOND_MASK) {
            reward = 2 ether; // 2 SYBL
        }
        return reward;
    }

    /**
     * @dev Update the token generation factor
     */
    function updateTpu(uint256 newTpu) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        tokenGenerationFactor = newTpu;
    }

    struct ListenerBalanceOnContent {
        uint8 tokenType;
        uint256 balance;
    }

    function withdrawFounds() external virtual override whenNotPaused {
        _withdraw(msg.sender);
    }

    function withdrawFounds(address user) external virtual override onlyRole(SybelRoles.ADMIN) whenNotPaused {
        _withdraw(user);
    }

    function updateContentBadge(uint256 contentId, uint256 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateContentBadge(contentId, badge);
    }

    function updateListenerBadge(address listener, uint64 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateListenerBadge(listener, badge);
    }
}
