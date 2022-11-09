// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./MultiVestingWallets.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

/// @dev error throwned when the creation param are invalid
error InvalidCreationParam();
error AlreadyUsedId();
/// @dev error throwned when the group isn't existant
error InexistantGroup();
/// @dev error when the supply of the group is not sufficiant
error InsuficiantGroupSupply();

contract VestingWalletFactory is SybelAccessControlUpgradeable {
    // The cap of sybl token propose to vester
    uint96 internal constant SYBL_VESTING_CAP = 1_500_000_000 ether;

    /**
     * @dev Represent the different vesting group
     */
    struct VestingGroup {
        // First storage slot (remain 15 bytes)
        uint96 rewardCap;
        uint96 supply;
        uint32 duration;
        uint16 initialDropPerthousand; // Initial drop on 1 / 1000
        bool isRevocable;
    }

    // The total amount of sybel minted for the investor's
    uint256 internal totalGroupCap;

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * @dev Access our multi vesting wallets
     */
    MultiVestingWallets private multiVestingWallets;

    /**
     * @dev Map of id to vesting group
     */
    mapping(uint8 => VestingGroup) private vestingGroup;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// Event emitted when a new vesting group is created
    event GroupAdded(uint8 indexed id, uint96 rewardCap, uint16 initialDropPerthousand, uint32 duration);
    event GroupSupplyTransfer(uint8 indexed initialId, uint8 indexed targetId, uint96 amount);
    event GroupUserAdded(uint8 indexed id, address benefiary, uint96 reward);

    function initialize(address sybelTokenAddr, address multiVestingWalletAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grand the vesting creator role to the owner
        _grantRole(SybelRoles.VESTING_CREATOR, msg.sender);

        // Init our sybel token and multi vesting wallet
        sybelToken = SybelToken(sybelTokenAddr);
        multiVestingWallets = MultiVestingWallets(multiVestingWalletAddr);
    }

    /**
     * @notice Create a new vesting group
     */
    function addVestingGroup(
        uint8 id,
        uint96 rewardCap,
        uint16 initialDropPerthousand,
        uint32 duration,
        bool revocable
    ) external onlyRole(SybelRoles.ADMIN) {
        _addVestingGroup(id, rewardCap, initialDropPerthousand, duration, revocable);
    }

    /**
     * @dev Add a new vesting group
     */
    function _addVestingGroup(
        uint8 id,
        uint96 rewardCap,
        uint16 initialDropPerthousand,
        uint32 duration,
        bool revocable
    ) private whenNotPaused {
        if (rewardCap == 0) revert NoReward();
        if (duration == 0 || initialDropPerthousand > 1000 || rewardCap + totalGroupCap > SYBL_VESTING_CAP)
            revert InvalidCreationParam();
        if (vestingGroup[id].rewardCap != 0) revert AlreadyUsedId();
        // Increase the total group supply
        totalGroupCap += rewardCap;
        // Build and save this group
        vestingGroup[id] = VestingGroup({
            rewardCap: rewardCap,
            supply: 0,
            duration: duration,
            initialDropPerthousand: initialDropPerthousand,
            isRevocable: revocable
        });
        // Emit the event
        emit GroupAdded(id, rewardCap, initialDropPerthousand, duration);
    }

    /**
     * @notice Transfer a group reserve to another one
     */
    function transferGroupReserve(
        uint8 initialId,
        uint8 targetId,
        uint96 amount
    ) external whenNotPaused onlyRole(SybelRoles.ADMIN) {
        // Ensure the group as enough supply
        VestingGroup storage initialGroup = _getSafeVestingGroup(initialId);
        if (initialGroup.supply > initialGroup.rewardCap - amount) revert InsuficiantGroupSupply();
        VestingGroup storage targetGroup = _getSafeVestingGroup(targetId);

        // Transfer the founds
        initialGroup.rewardCap -= amount;
        targetGroup.rewardCap += amount;
        // Emit the event
        emit GroupSupplyTransfer(initialId, targetId, amount);
    }

    /**
     * @dev Get the group for the given id
     */
    function getVestingGroup(uint8 id) external view returns (VestingGroup memory) {
        return _getSafeVestingGroup(id);
    }

    /**
     * @dev Get the group for the given id
     */
    function _getSafeVestingGroup(uint8 id) private view returns (VestingGroup storage group) {
        group = vestingGroup[id];
        if (group.rewardCap == 0) revert InexistantGroup();
    }

    /**
     * @dev Create a new vesting wallet
     */
    function addVestingWallet(
        address beneficiary,
        uint256 reward,
        uint8 groupId,
        uint48 startDate
    ) external onlyRole(SybelRoles.VESTING_CREATOR) whenNotPaused {
        // Ensure all the param are correct
        if (reward == 0) revert NoReward();
        if (beneficiary == address(0)) revert InvalidAddress();
        // Find the group and check basic properties
        VestingGroup storage group = _getSafeVestingGroup(groupId);
        if (group.supply + reward > group.rewardCap) revert RewardTooLarge();

        // Compute the initial drop if needed
        uint256 initialDrop;
        if (group.initialDropPerthousand != 0) {
            unchecked {
                initialDrop = (reward * group.initialDropPerthousand) / 1000;
            }
        }
        // Update the group supply
        group.supply += uint96(reward);

        // Create the vesting group
        multiVestingWallets.createVest(beneficiary, reward, initialDrop, group.duration, startDate, group.isRevocable);

        // Emit the event's
        emit GroupUserAdded(groupId, beneficiary, uint96(reward));
    }

    /**
     * @dev Create a new vesting wallet
     */
    function addVestingWalletBatch(
        address[] calldata beneficiaries,
        uint256[] calldata rewards,
        uint8 groupId,
        uint48 startDate
    ) external onlyRole(SybelRoles.VESTING_CREATOR) whenNotPaused {
        // Ensure all the param are correct
        if (beneficiaries.length == 0 || beneficiaries.length != rewards.length) revert InvalidArray();

        // Find the group and check basic properties
        VestingGroup storage group = _getSafeVestingGroup(groupId);

        // Compute the total rewards to ensure it don't exceed the group cap
        uint256 totalReward;
        uint256[] memory initialDrops = new uint256[](rewards.length);
        for (uint256 index; index < rewards.length; ) {
            unchecked {
                // Increase the total rewards
                totalReward += rewards[index];
                // Compute the initial drops
                if (group.initialDropPerthousand != 0) {
                    initialDrops[index] = (rewards[index] * group.initialDropPerthousand) / 1000;
                }
                // Increment the index
                ++index;
            }
        }

        // Ensure we don't exceed the caps
        if (group.supply + totalReward > group.rewardCap) revert RewardTooLarge();

        // Update the group supply
        group.supply += uint96(totalReward);

        // Create the vests
        multiVestingWallets.createVestBatch(
            beneficiaries,
            rewards,
            initialDrops,
            group.duration,
            startDate,
            group.isRevocable
        );

        // Emit the event's
        for (uint256 index; index < beneficiaries.length; ) {
            emit GroupUserAdded(groupId, beneficiaries[index], uint96(rewards[index]));

            // Increment the index
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice Revoke a user vest wallet, and so reduce the group supply by the amount unlocked
     */
    function revokeUserVest(uint8 groupId, uint24 vestId) external onlyRole(SybelRoles.VESTING_CREATOR) whenNotPaused {
        // Get our group and the previous sybl balance of the contract
        VestingGroup storage group = _getSafeVestingGroup(groupId);

        // Perform the vest release
        uint96 remainingAmount = multiVestingWallets.revoke(vestId);

        // Decrement the supply of the released amount
        group.supply -= remainingAmount;
    }
}
