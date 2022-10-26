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
import "../utils/WadMath.sol";
import "hardhat/console.sol";

// Error throwned by this contract
error TooMuchCcu();
error InvalidReward();

/**
 * @dev Represent our rewarder contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Rewarder is IRewarder, SybelAccessControlUpgradeable, ContentBadges, ListenerBadges, PushPullReward {
    // The cap of frak token we can mint for the reward
    uint96 private constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint96 private constant SINGLE_REWARD_CAP = 1_000_000 ether;

    // Maximum data we can treat in a batch manner
    uint8 private constant MAX_BATCH_AMOUNT = 20;
    uint16 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

    /**
     * @dev factor user to compute the number of token to generate (on 1e18 decimals)
     */
    uint256 public tokenGenerationFactor;

    /**
     * @dev The total frak minted for reward
     */
    uint96 public totalFrakMinted;

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
        referralPool = ReferralPool(referralAddr);

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
        if (contentIds.length != listenCounts.length || contentIds.length > MAX_BATCH_AMOUNT) revert InvalidArray();
        // Get our current tpu in memory
        uint256 _tpu = tokenGenerationFactor;
        // Get our total amopunt to be minted
        uint96 totalMintForUser;
        uint96 totalMintForOwners;
        uint96 totalMintForReferral;
        uint96 totalMintForContent;
        // Iterate over each content
        for (uint256 i; i < contentIds.length; ) {
            // TODO : Do we need to ensure that the podcast exist ???
            // Ensure we don't exceed the max ccu / content
            if (listenCounts[i] > MAX_CCU_PER_CONTENT) revert TooMuchCcu();
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
                    tpu: _tpu,
                    listenCount: listenCounts[i],
                    hasOnePayedToken: hasOnePayedToken,
                    balances: balances
                });
                (
                    uint96 userReward,
                    uint96 ownerReward,
                    uint96 referralPoolReward,
                    uint96 contentPoolReward
                ) = computeContentReward(computeRewardParam);
                unchecked {
                    totalMintForUser += userReward;
                    totalMintForOwners += ownerReward;
                    totalMintForReferral += referralPoolReward;
                    totalMintForContent += contentPoolReward;
                }
            }

            // Increase our index
            unchecked {
                ++i;
            }
        }
        // If we don't find any reward for the user, exit directly
        if (totalMintForUser == 0) return;

        // Get the listener badge and recompute his reward
        uint64 listenerBadge = getListenerBadge(listener);

        // Update the total mint for user with his listener badges
        totalMintForUser = uint96((uint256(totalMintForUser) * listenerBadge) / 1 ether);

        // Register the amount for listener
        _addFoundsUnchecked(listener, totalMintForUser);

        // Compute the total amount to mint, and ensure we don't exeed our cap
        uint96 totalMint = totalMintForUser + totalMintForOwners + totalMintForContent + totalMintForReferral;
        // Update the total mint for user with his listener badges
        if (totalMint + totalFrakMinted > REWARD_MINT_CAP) revert InvalidReward();
        // If good, update our total frak minted and emit the event
        unchecked {
            totalFrakMinted += totalMint;
        }
        emit UserRewarded(
            listener,
            contentIds,
            listenCounts,
            totalMintForUser,
            totalMintForContent + totalMintForReferral
        );

        // If we got reward for the pool, mint them
        if (totalMintForContent > 0 || totalMintForReferral > 0) {
            sybelToken.mint(address(this), totalMintForUser + totalMintForOwners);
            sybelToken.mint(address(contentPool), totalMintForContent);
            sybelToken.mint(address(referralPool), totalMintForReferral);
        } else {
            // Otherwise, only mint for this contract
            sybelToken.mint(address(this), totalMintForUser + totalMintForOwners);
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
        for (uint8 i; i < types.length; ++i) {
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
        uint256 tpu;
        uint256 listenCount;
        bool hasOnePayedToken;
        ListenerBalanceOnContent[] balances;
    }

    /**
     * @dev Mint the reward for the given user, and take in account his balances for the given content
     */
    function computeContentReward(ComputeRewardParam memory param)
        private
        returns (
            uint96 userReward,
            uint96 ownerReward,
            uint96 referralPoolReward,
            uint96 contentPoolReward
        )
    {
        // The user have a balance we can continue
        uint256 contentBadge = getContentBadge(param.contentId);
        // Mint each token for each fraction
        uint256 earningFactor;
        for (uint8 i; i < param.balances.length; ++i) {
            unchecked {
                earningFactor += param.balances[i].balance * baseRewardForTokenType(param.balances[i].tokenType); // On 1e18
            }
        }
        // If no reward, directly exit
        if (earningFactor == 0) {
            return (0, 0, 0, 0);
        }
        // Compute our total reward (by applying the content badge, TPY, and number of listen performed)
        // We got earning factor on 1e18, contentBadge on 1e18 and tpu on 1e18, so dividing by 1e18 * 1e18 (So 1e36) to get a 1e18 amount to mint
        uint96 totalReward = uint96(
            (earningFactor * contentBadge * param.listenCount * param.tpu) / (1 ether * 1 ether)
        );
        // Ensure the reward isn't too large, and also ensure it fit inside a uint96
        if (totalReward > SINGLE_REWARD_CAP) revert InvalidReward();

        // Then split the payment for owner and user
        unchecked {
            userReward = (totalReward * 35) / 100;
            ownerReward = totalReward - userReward;
        }

        // If the user has one payed token, send it to the different pools
        if (param.hasOnePayedToken) {
            // Add the reward to the content pool
            unchecked {
                contentPoolReward = totalReward / 10;
            }
            contentPool.addReward(param.contentId, contentPoolReward);

            // Compute the reward for the referral
            uint96 baseReferralReward;
            unchecked {
                baseReferralReward = (totalReward * 3) / 50;
            }
            referralPoolReward = uint96(
                referralPool.payAllReferer(param.contentId, param.listener, baseReferralReward)
            );

            // Decrease the owner reward by the pool amount used
            unchecked {
                ownerReward -= contentPoolReward - referralPoolReward;
            }
        }
        // Save the amount for the owner
        address owner = sybelInternalTokens.ownerOf(param.contentId);
        _addFoundsUnchecked(owner, ownerReward);
        // TODO : For each content
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
    }

    /**
     * @dev Update the token generation factor
     */
    function updateTpu(uint256 newTpu) external onlyRole(SybelRoles.ADMIN) {
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
