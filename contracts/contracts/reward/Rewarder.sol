// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IRewarder.sol";
import "../badges/access/PaymentBadgesAccessor.sol";
import "../utils/SybelMath.sol";
import "../utils/SybelRoles.sol";
import "../tokens/SybelInternalTokens.sol";
import "../tokens/SybelToken.sol";
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
     */
    mapping(address => uint256) public pendingRewards;

    /**
     * @dev Event emitted when a user is rewarded for his listen
     */
    event UserRewarded(
        uint256 podcastId,
        address user,
        uint256 listenCount,
        uint256 amountPaid,
        ListenerBalanceOnPodcast[] listenerBalance
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
        address podcastBadgesAddr
    ) external initializer {
        /*
        // Only for v1 deployment
        __SybelAccessControlUpgradeable_init();
        __PaymentBadgesAccessor_init(listenerBadgesAddr, podcastBadgesAddr);

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

    function migrateToV4(address podcastBadgesAddr) external reinitializer(4) {
        // Only for v4 upgrade
        podcastBadges = IPodcastBadges(podcastBadgesAddr);
    }

    /**
     * @dev Pay a user for all the listening he have done on different podcast
     */
    function payUser(
        address listener,
        uint256[] calldata podcastIds,
        uint16[] calldata listenCounts
    ) external override onlyRole(SybelRoles.REWARDER) whenNotPaused {
        require(
            podcastIds.length == listenCounts.length,
            "SYB: Can't pay of podcast for id and listen of different length"
        );
        require(podcastIds.length <= MAX_BATCH_AMOUNT, "SYB: Can't treat more than 20 items at a time");
        // Get our total amopunt to be minted
        uint256 totalAmountToMint = 0;
        // Iterate over each podcast
        for (uint256 i = 0; i < podcastIds.length; ++i) {
            // Find the balance of the listener for this podcast
            (ListenerBalanceOnPodcast[] memory balances, bool hasAtLeastOneBalance) = getListenerBalanceForPodcast(
                listener,
                podcastIds[i]
            );
            // If no balance mint a Standard NFT
            if (!hasAtLeastOneBalance) {
                sybelInternalTokens.mint(listener, SybelMath.buildStandardNftId(podcastIds[i]), 1);
                // And then recompute his balance
                (balances, hasAtLeastOneBalance) = getListenerBalanceForPodcast(listener, podcastIds[i]);
            }
            // If he as at least one balance
            if (hasAtLeastOneBalance) {
                totalAmountToMint += mintForUser(listener, podcastIds[i], listenCounts[i], balances);
            }
        }
        // Once we have iterate over each item, if we got a positive mint amount, mint it
        if (totalAmountToMint > 0) {
            sybelToken.mint(address(this), totalAmountToMint);
        }
    }

    /**
     * @dev Find the balance of the given user on each tokens
     */
    function getListenerBalanceForPodcast(address listener, uint256 podcastId)
        private
        view
        returns (ListenerBalanceOnPodcast[] memory, bool hasToken)
    {
        // The different types we will fetch
        uint8[] memory types = SybelMath.payableTokenTypes();
        // Build the ids for eachs types
        uint256[] memory tokenIds = SybelMath.buildSnftIds(podcastId, types);
        // Build our initial balance map
        ListenerBalanceOnPodcast[] memory balances = new ListenerBalanceOnPodcast[](types.length);
        // Boolean used to know if the user have a balance
        bool hasAtLeastOneBalance = false;
        // Iterate over each types to find the balances
        for (uint8 i = 0; i < types.length; ++i) {
            // TODO : Batch balances of to be more gas efficient ??
            // Get the balance and build our balance on podcast object
            uint256 balance = sybelInternalTokens.balanceOf(listener, tokenIds[i]);
            balances[i] = ListenerBalanceOnPodcast(types[i], balance);
            // Update our has at least one balance object
            hasAtLeastOneBalance = hasAtLeastOneBalance || balance > 0;
        }
        return (balances, hasAtLeastOneBalance);
    }

    /**
     * @dev Mint the reward for the given user, and take in account his balances for the given podcast
     */
    function mintForUser(
        address listener,
        uint256 podcastId,
        uint16 listenCount,
        ListenerBalanceOnPodcast[] memory balances
    ) private returns (uint256) {
        // The user have a balance we can continue
        uint256 podcastBadge = podcastBadges.getBadge(podcastId);
        // Amout we will mint for user and for owner
        uint256 totalAmountToMint = 0;
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
                podcastBadge,
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
        address podcastOwner = sybelInternalTokens.ownerOf(podcastId);
        pendingRewards[podcastOwner] += amountForOwner;
        // Emit the reward event
        emit UserRewarded(podcastId, listener, listenCount, amountForListener, balances);
        // Return the total amount to mint
        return totalAmountToMint;
    }

    /**
     * @dev Compute the user reward for the given fraction
     */
    function computeUserRewardForFraction(
        uint256 balance,
        uint8 tokenType,
        uint256 podcastBadge, // Badge on 1e18 decimals
        uint16 consumedContentUnit
    ) private view returns (uint256) {
        // Compute the earning factor
        uint256 earningFactor = balance * baseRewardForTokenType(tokenType); // On 1e18 decimals
        // Compute the badge reward (and divied it by 1e18 since we have 2 value on 1e18 decimals)
        uint256 badgeReward = (podcastBadge * earningFactor * consumedContentUnit);
        // Add our token generation factor to the computation, and dived it by 1e18
        return (badgeReward * tokenGenerationFactor) / (1 ether * 1 ether);
    }

    /**
     * @dev Get the base reward to the given token type
     * We use a pure function instead of a mapping to economise on storage read,
     * and since this reawrd shouldn't evolve really fast
     */
    function baseRewardForTokenType(uint8 tokenType) private pure returns (uint96) {
        uint96 reward = 0;
        if (tokenType == SybelMath.TOKEN_TYPE_STANDARD_MASK) {
            reward = 0.01 ether; // 0.01 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_CLASSIC_MASK) {
            reward = 0.1 ether; // 0.1 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_RARE_MASK) {
            reward = 0.5 ether; // 0.5 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_EPIC_MASK) {
            reward = 1 ether; // 1 SYBL
        } else if (tokenType == SybelMath.TOKEN_TYPE_LEGENDARY_MASK) {
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

    struct ListenerBalanceOnPodcast {
        uint8 tokenType;
        uint256 balance;
    }

    /**
     * Withdraw the user pending founds
     */
    function withdrawFounds(address user) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        require(user != address(0), "SYB: Can't withdraw referral founds for the 0 address");
        // Ensure the user have a pending reward
        uint256 pendingReward = pendingRewards[user];
        require(pendingReward > 0, "SYB: The user havn't any pending reward");
        // Ensure we have enough founds on this contract to pay the user
        uint256 contractBalance = sybelToken.balanceOf(address(this));
        require(contractBalance > pendingReward, "SYB: Contract havn't enough founds");
        // Reset the user pending balance
        pendingRewards[user] = 0;
        // Emit the withdraw event
        emit RewardWithdrawed(user, pendingReward);
        // Perform the transfer of the founds
        sybelToken.transfer(user, pendingReward);
    }
}
