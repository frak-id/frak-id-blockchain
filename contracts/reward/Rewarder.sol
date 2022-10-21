// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IRewarder.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";

/**
 * @dev Represent our rewarder contract
 */
/// @custom:security-contact crypto-support@sybel.co
contract Rewarder is IRewarder, SybelAccessControlUpgradeable, PaymentBadgesAccessor {
    // Maximum data we can treat in a batch manner
    uint8 private constant MAX_BATCH_AMOUNT = 20;

    /**
     * @dev Access our internal tokens
     */
    SybelInternalTokens private sybelInternalTokens;

    /**
     * @dev Access our governance token
     */
    /// @custom:oz-renamed-from tokenSybelEcosystem
    SybelToken private sybelToken;

    /**
     * @dev factor user to compute the number of token to generate (on 1e18 decimals)
     */
    uint256 public tokenGenerationFactor;

    /**
     * The pending reward for the given address
     * TODO : Can be uint96 (since sybl cap is a 1.5 billion 1e18 so it shouldn't exceed that value)
     */
    mapping(address => uint256) public pendingRewards;

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserRewarded(
        uint256 indexed contentId,
        address indexed user,
        uint256 listenCount,
        uint256 amountPaid
    );

    /**
     * @dev Event emitted when a reward is minted from our frak token
     */
    event RewardMinted(
        address indexed user,
        uint256 mintAmount
    );

    /**
     * @dev Event emitted when a user withdraw his pending reward
     */
    event RewardWithdrawed(address user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address syblTokenAddr,
        address internalTokenAddr,
        address listenerBadgesAddr,
        address contentBadgesAddr
    ) external initializer {
        /*
        // Only for v1 deployment
        __SybelAccessControlUpgradeable_init();
        __PaymentBadgesAccessor_init(listenerBadgesAddr, contentBadgesAddr);

        sybelInternalTokens = SybelInternalTokens(internalTokenAddr);
        sybelToken = SybelToken(syblTokenAddr);

        // Default TPU
        tokenGenerationFactor = 4.22489708885 ether;

        // Grant the rewarder role to the contract deployer
        _grantRole(SybelRoles.REWARDER, msg.sender);
        */
    }

    function migrateToV2(address sybelTokenAddr) external reinitializer(2) {
        /*
        // Only for v2 upgrade
        sybelToken = SybelToken(sybelTokenAddr);
        */
    }

    function migrateToV3() external reinitializer(3) {
        /*
        // Only for v3 upgrade
        tokenGenerationFactor = 4.22489708885 ether;
        */
    }

    function migrateToV4(address contentBadgesAddr) external reinitializer(4) {
        // Only for v4 upgrade
        contentBadges = IContentBadges(contentBadgesAddr);
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
        uint256 totalAmountToMint = 0;
        // Iterate over each content
        for (uint256 i = 0; i < contentIds.length; ++i) {
            // Find the balance of the listener for this content
            (ListenerBalanceOnContent[] memory balances, bool hasAtLeastOneBalance) = getListenerBalanceForContent(
                listener,
                contentIds[i]
            );
            // If no balance mint a Standard NFT
            if (!hasAtLeastOneBalance) {
                sybelInternalTokens.mint(listener, SybelMath.buildFreeNftId(contentIds[i]), 1);
                // And then recompute his balance
                (balances, hasAtLeastOneBalance) = getListenerBalanceForContent(listener, contentIds[i]);
            }
            // If he as at least one balance
            if (hasAtLeastOneBalance) {
                totalAmountToMint += mintForUser(listener, contentIds[i], listenCounts[i], balances);
            }
        }
        // Once we have iterate over each item, if we got a positive mint amount, mint it
        if (totalAmountToMint > 0) {
            emit RewardMinted(listener, totalAmountToMint);
            sybelToken.mint(address(this), totalAmountToMint);
        }
    }

    /**
     * @dev Find the balance of the given user on each tokens
     */
    function getListenerBalanceForContent(address listener, uint256 contentId)
        private
        view
        returns (ListenerBalanceOnContent[] memory, bool hasToken)
    {
        // The different types we will fetch
        uint8[] memory types = SybelMath.payableTokenTypes();
        // Build the ids for eachs types
        uint256[] memory tokenIds = SybelMath.buildSnftIds(contentId, types);
        // Build our initial balance map
        ListenerBalanceOnContent[] memory balances = new ListenerBalanceOnContent[](types.length);
        // Boolean used to know if the user have a balance
        bool hasAtLeastOneBalance = false;
        // Get the balance
        uint256[] memory tokenBalances = sybelInternalTokens.balanceOfIdsBatch(listener, tokenIds);
        // Iterate over each types to find the balances
        for (uint8 i = 0; i < types.length; ++i) {
            // Get the balance and build our balance on content object
            uint256 balance = tokenBalances[i];
            balances[i] = ListenerBalanceOnContent(types[i], tokenBalances[i]);
            // Update our has at least one balance object
            hasAtLeastOneBalance = hasAtLeastOneBalance || balance > 0;
        }
        return (balances, hasAtLeastOneBalance);
    }

    /**
     * @dev Mint the reward for the given user, and take in account his balances for the given content
     */
    function mintForUser(
        address listener,
        uint256 contentId,
        uint16 listenCount,
        ListenerBalanceOnContent[] memory balances
    ) private returns (uint256 totalAmountToMint) {
        // The user have a balance we can continue
        uint256 contentBadge = contentBadges.getBadge(contentId);
        // Mint each token for each fraction
        for (uint256 i = 0; i < balances.length; ++i) {
            if (balances[i].balance <= 0) {
                // Jump this iteration if the user havn't go any balance of this token types
                continue;
            }
            // Compute the amount for the owner and the users
            totalAmountToMint += computeUserRewardForFraction(
                balances[i].balance,
                balances[i].tokenType,
                contentBadge,
                listenCount
            );
        }
        // If nothing to mint, directly exit
        if (totalAmountToMint == 0) {
            return 0;
        }
        uint256 amountForOwner = totalAmountToMint / 2;
        uint256 baseAmountForListener = totalAmountToMint - amountForOwner;
        // Handle the user badge for his amount
        uint64 listenerBadge = listenerBadges.getBadge(listener);
        uint256 amountForListener = (baseAmountForListener * listenerBadge) / 1 ether;
        // Register the amount for listener
        pendingRewards[listener] += amountForListener;
        // Register the amount for the owner
        address owner = sybelInternalTokens.ownerOf(contentId);
        pendingRewards[owner] += amountForOwner;
        // Emit the reward eventcontentId
        emit UserRewarded(contentId, listener, listenCount, amountForListener);
        // Return the total amount to mint
        return totalAmountToMint;
    }

    /**
     * @dev Compute the user reward for the given fraction
     */
    function computeUserRewardForFraction(
        uint256 balance,
        uint8 tokenType,
        uint256 contentBadge, // Badge on 1e18 decimals
        uint16 consumedContentUnit
    ) private view returns (uint256) {
        // Compute the earning factor
        uint256 earningFactor = balance * baseRewardForTokenType(tokenType); // On 1e18 decimals
        // Compute the badge reward (and divied it by 1e18 since we have 2 value on 1e18 decimals)
        uint256 badgeReward = (contentBadge * earningFactor * consumedContentUnit);
        // Add our token generation factor to the computation, and dived it by 1e18
        return (badgeReward * tokenGenerationFactor) / (1 ether * 1 ether);
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

    /**
     * Withdraw the user pending founds
     */
    function withdrawFounds(address user) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        require(user != address(0), "SYB: invlid address");
        // Ensure the user have a pending reward
        uint256 pendingReward = pendingRewards[user];
        require(pendingReward > 0, "SYB: no pending reward");
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = sybelToken.balanceOf(address(this));
        require(contractBalance > pendingReward, "SYB: not enough founds");
        // Reset the user pending balance
        pendingRewards[user] = 0;
        // Emit the withdraw event
        emit RewardWithdrawed(user, pendingReward);
        // Perform the transfer of the founds
        sybelToken.transfer(user, pendingReward);
    }
}
