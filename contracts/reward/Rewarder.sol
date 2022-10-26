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
    using SybelMath for uint256;

    // The cap of frak token we can mint for the reward
    uint256 private constant REWARD_MINT_CAP = 1_500_000_000 ether;
    uint256 private constant SINGLE_REWARD_CAP = 1_000_000 ether;

    // Maximum data we can treat in a batch manner
    uint256 private constant MAX_BATCH_AMOUNT = 20;
    uint256 private constant MAX_CCU_PER_CONTENT = 300; // The mac ccu per content, currently maxed at 5hr

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

    struct ToBeMinted {
        uint256 user;
        uint256 owners;
        uint256 referral;
        uint256 content;
    }

    function payUser(
        address listener,
        uint256[] calldata contentIds,
        uint16[] calldata listenCounts
    ) external onlyRole(SybelRoles.REWARDER) whenNotPaused {
        // Ensure we got valid data
        if (contentIds.length != listenCounts.length || contentIds.length > MAX_BATCH_AMOUNT) revert InvalidArray();

        // Load our current tpu in memory
        uint256 _tpu = tokenGenerationFactor;

        // Get the data we will need in this level
        uint256 totalUser;
        uint256 totalOwners;
        uint256 totalReferral;
        uint256 totalContent;

        // Get all the paied fraktion types
        uint8[] memory fraktionTypes = SybelMath.payableTokenTypes();

        // Iterate over each content the user listened
        for (uint256 i; i < contentIds.length; ) {
            // TODO : Also ensure this podcast is minted
            // Ensure we don't exceed the max ccu / content
            if (listenCounts[i] > MAX_CCU_PER_CONTENT) revert TooMuchCcu();
            // Extract the content id
            uint256 contentId = contentIds[i];

            // Build the ids for eachs fraktion that can generate reward, and get the user balance for each one if this fraktions
            uint256[] memory fraktionIds = SybelMath.buildSnftIds(contentIds[i], fraktionTypes);
            uint256[] memory tokenBalances = sybelInternalTokens.balanceOfIdsBatch(listener, fraktionIds);

            // Boolean used to know if the user have one paied fraktion
            bool hasOnePaiedFraktion;

            // The content earning factor of the user
            uint256 earningFactor;

            // Iterate over each balance to compute the earning factor
            for (uint256 balanceIndex; balanceIndex < tokenBalances.length; ) {
                uint256 balance = tokenBalances[balanceIndex];
                // Check if that was a paid fraktion or not
                hasOnePaiedFraktion =
                    hasOnePaiedFraktion ||
                    (SybelMath.isPayedTokenToken(fraktionTypes[balanceIndex]) && balance > 0);
                // Increase the earning faktor
                unchecked {
                    earningFactor += balance * baseRewardForTokenType(fraktionTypes[balanceIndex]); // On 1e18 decimals
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
            // TODO : Compare if the division is better placed here on before in the loop, probably here
            uint256 totalReward = (earningFactor * contentBadge * listenCounts[i] * _tpu) / (1 ether * 1 ether); // Same here should use WaD multiplier
            // Ensure the reward isn't too large
            if (totalReward > SINGLE_REWARD_CAP) revert InvalidReward();

            // Then split the payment for owner and user
            uint256 userReward;
            uint256 ownerReward;
            uint256 contentPoolReward;
            uint256 referralPoolReward;
            unchecked {
                userReward = (totalReward * 35) / 100;
                ownerReward = totalReward - userReward;
            }

            if (hasOnePaiedFraktion) {
                // Compute the reward for the content pool and the referral
                uint256 baseReferralReward;
                unchecked {
                    contentPoolReward = totalReward / 10;
                    baseReferralReward = (totalReward * 3) / 50;
                }
                // Send the reward to the content ool and referral pool // TODO : Multicall possible here ? Even if distinct contract ??
                contentPool.addReward(contentId, contentPoolReward);
                referralPoolReward = referralPool.payAllReferer(contentId, listener, baseReferralReward);

                // Decrease the owner reward by the pool amount used
                unchecked {
                    ownerReward -= contentPoolReward - referralPoolReward;
                }
            }
            // Save the amount for the owner
            address owner = sybelInternalTokens.ownerOf(contentId);
            _addFoundsUnchecked(owner, ownerReward);

            // Finally, increase all the amount to be minted
            unchecked {
                totalContent += contentPoolReward;
                totalReferral += referralPoolReward;
                totalUser += userReward;
                totalOwners += ownerReward;

                // And increase our content counter
                ++i;
            }
        }

        // Then outside of our loop find the user badge
        uint256 listenerBadge = getListenerBadge(listener);

        // Update the total mint for user with his listener badges
        totalUser = wadMulDivDown(totalUser, listenerBadge);

        // Register the amount for listener
        _addFoundsUnchecked(listener, totalUser);

        // Compute the total amount to mint, and ensure we don't exeed our cap
        unchecked {
            uint256 totalMint = totalUser + totalOwners + totalContent + totalReferral;
            if (totalMint + totalFrakMinted > REWARD_MINT_CAP) revert InvalidReward();
            totalFrakMinted += totalMint;
        }
        emit UserRewarded(listener, contentIds, listenCounts, totalUser, totalContent + totalReferral);

        // If we got reward for the pool, mint them
        if (totalContent > 0 || totalReferral > 0) {
            sybelToken.mint(address(this), totalUser + totalOwners);
            sybelToken.mint(address(contentPool), totalContent);
            sybelToken.mint(address(referralPool), totalReferral);
        } else {
            // Otherwise, only mint for this contract
            sybelToken.mint(address(this), totalUser + totalOwners);
        }
    }

    function wadMulDivDown(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            // Divide x * y by the 1e18 (decimals).
            z := div(mul(x, y), 1000000000000000000)
        }
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function baseRewardForTokenType(uint8 tokenType) private pure returns (uint256 reward) {
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

    function updateListenerBadge(address listener, uint256 badge)
        external
        override
        onlyRole(SybelRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateListenerBadge(listener, badge);
    }
}
