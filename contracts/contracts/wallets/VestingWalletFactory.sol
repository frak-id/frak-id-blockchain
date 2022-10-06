// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./MultiVestingWallets.sol";
import "../tokens/SybelToken.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

contract VestingWalletFactory is SybelAccessControlUpgradeable {
    // The cap of sybl token propose to vester
    uint256 internal constant SYBL_VESTING_CAP = 1_500_000_000 ether;
    // The id of the different groups
    uint8 internal constant GROUP_INVESTOR_ID = 1;
    uint8 internal constant GROUP_TEAM_ID = 2;
    uint8 internal constant GROUP_PRE_SALES_1_ID = 10;
    uint8 internal constant GROUP_PRE_SALES_2_ID = 11;
    uint8 internal constant GROUP_PRE_SALES_3_ID = 12;
    uint8 internal constant GROUP_PRE_SALES_4_ID = 13;

    /**
     * @dev Represent the different vesting group
     */
    struct VestingGroup {
        uint256 rewardCap;
        uint256 supply;
        uint64 duration;
        uint64 delay;
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
    event VestingGroupAdded(uint8 id, uint256 rewardCap, uint64 duration, uint64 delay);

    function initialize(address sybelTokenAddr, address multiVestingWalletAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grand the vesting creator role to the owner
        _grantRole(SybelRoles.VESTING_CREATOR, msg.sender);

        // Init our sybel token
        sybelToken = SybelToken(sybelTokenAddr);
        // Init our multi vesting wallets
        multiVestingWallets = MultiVestingWallets(multiVestingWalletAddr);

        // Add all the initial group
        addInitialGroup();
    }

    /**
     * @dev Add all the initial vesting group
     */
    function addInitialGroup() internal {
        // Investor and team vesting groups
        _addVestingGroup(
            GROUP_INVESTOR_ID,
            300_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        _addVestingGroup(
            GROUP_TEAM_ID,
            300_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        // Pre sales groupes
        _addVestingGroup(
            GROUP_PRE_SALES_1_ID,
            100_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        _addVestingGroup(
            GROUP_PRE_SALES_2_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        _addVestingGroup(
            GROUP_PRE_SALES_3_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        _addVestingGroup(
            GROUP_PRE_SALES_4_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
    }

    /**
     * @dev Add a new vesting group
     */
    function _addVestingGroup(
        uint8 id,
        uint256 rewardCap,
        uint64 duration,
        uint64 delay
    ) internal onlyRole(SybelRoles.ADMIN) whenNotPaused {
        require(vestingGroup[id].delay == 0, "SYB: This vesting group already exist");
        require(rewardCap > 0, "SYB: The reward cap should be superior to 0");
        require(duration > 0, "SYB: The duration should be superior to 0");
        require(rewardCap + totalGroupCap <= SYBL_VESTING_CAP, "SYB: Reward cap exceeding total cap for vesting");
        // Increase the total group supply
        totalGroupCap += rewardCap;
        // Build and save this group
        vestingGroup[id] = VestingGroup(rewardCap, 0, duration, delay);
        // Emit the event
        emit VestingGroupAdded(id, rewardCap, duration, delay);
    }

    /**
     * @dev Get the group for the given id
     */
    function getVestingGroup(uint8 id) external view returns (VestingGroup memory) {
        return vestingGroup[id];
    }

    /**
     * @dev Create a new vesting wallet
     */
    function addVestingWallet(
        address beneficiary,
        uint256 reward,
        uint8 groupId
    ) external onlyRole(SybelRoles.VESTING_CREATOR) whenNotPaused {
        // Ensure all the param are correct
        require(reward > 0, "SYBL : Investor reward should be greater than 0");
        require(beneficiary != address(0), "SYB: Investor address shouldn't be 0");
        // Find the group and check basic properties
        VestingGroup storage group = vestingGroup[groupId];
        require(group.duration > 0, "SYB: This vesting group doesn't exist");
        require(group.supply + reward <= group.rewardCap, "SYB: Can't mint more than the group supply cap");
        // Mint the sybl token for this user
        sybelToken.mint(address(multiVestingWallets), reward);
        // Create the vesting group
        multiVestingWallets.createVest(beneficiary, reward, group.delay, group.duration);
    }
}
