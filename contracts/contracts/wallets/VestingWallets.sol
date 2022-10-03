// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "../tokens/SybelToken.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

contract VestingWallets is SybelAccessControlUpgradeable {
    // The cap of sybl token propose to vester
    uint256 internal constant SYBL_VESTING_CAP = 1_500_000_000 ether;
    // The id of the different groups
    uint8 internal constant GROUP_INVESTOR_ID = 1;
    uint8 internal constant GROUP_TEAM_ID = 2;
    uint8 internal constant GROUP_PRE_SALES_1_ID = 10;
    uint8 internal constant GROUP_PRE_SALES_2_ID = 11;
    uint8 internal constant GROUP_PRE_SALES_3_ID = 12;
    uint8 internal constant GROUP_PRE_SALES_4_ID = 13;

    // The total amount of sybel minted for the investor's
    uint256 internal totalGroupCap;

    /**
     * @dev Access our sybel token
     */
    SybelToken private sybelToken;

    /**
     * @dev Map address to all the vesting groups
     */
    mapping(address => mapping(uint8 => VestingWallet))
        private investorVestingWallets;

    /**
     * @dev Map address to all participating group ids
     */
    mapping(address => uint8[]) private investorToGroupIds;

    /**
     * @dev Map of id to vesting group
     */
    mapping(uint8 => VestingGroup) private vestingGroup;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    event VestingWalletCreated(
        address vesterAddress,
        address vestingWalletAddress,
        uint64 startTime,
        uint64 duration
    );

    event VestingWalletSupplyIncreased(
        address vesterAddress,
        address vestingWalletAddress,
        uint256 additionalReward
    );

    event VestingGroupAdded(
        uint8 id,
        uint256 rewardCap,
        uint64 duration,
        uint64 delay
    );

    function initialize(address sybelTokenAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Init our sybel token
        sybelToken = SybelToken(sybelTokenAddr);
        // Init the vester amount
        totalGroupCap = 0;

        // Add all the initial group
        addInitialGroup();
    }

    /**
     * @dev Add all the initial vesting group
     */
    function addInitialGroup() internal {
        // Investor and team vesting groups
        addVestingGroup(
            GROUP_INVESTOR_ID,
            300_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        addVestingGroup(
            GROUP_TEAM_ID,
            300_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        // Pre sales groupes
        addVestingGroup(
            GROUP_PRE_SALES_1_ID,
            100_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        addVestingGroup(
            GROUP_PRE_SALES_2_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        addVestingGroup(
            GROUP_PRE_SALES_3_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
        addVestingGroup(
            GROUP_PRE_SALES_4_ID,
            200_000_000 ether, // Reward cap
            52 weeks, // Duration
            0 // Delay before start of the linear curve
        );
    }

    /**
     * @dev Add a new vesting group
     */
    function addVestingGroup(
        uint8 id,
        uint256 rewardCap,
        uint64 duration,
        uint64 delay
    ) public onlyRole(SybelRoles.ADMIN) whenNotPaused {
        require(
            vestingGroup[id].delay == 0,
            "SYB: This vesting group already exist"
        );
        require(rewardCap > 0, "SYB: The reward cap should be superior to 0");
        require(duration > 0, "SYB: The duration should be superior to 0");
        require(
            rewardCap + totalGroupCap <= SYBL_VESTING_CAP,
            "SYB: The reward cap for this group exceed the total cap for vesting"
        );
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
    function getVestingGroup(uint8 id)
        external
        view
        returns (VestingGroup memory)
    {
        return vestingGroup[id];
    }

    /**
     * @dev Create a new vesting wallet
     */
    function addVestingWallet(
        address investor,
        uint256 reward,
        uint8 groupId
    ) external onlyRole(SybelRoles.ADMIN) whenNotPaused {
        // Ensure all the param are correct
        require(reward > 0, "SYBL : Investor reward should be greater than 0");
        require(investor != address(0), "SYB: Investor address shouldn't be 0");
        // Find the group and check basic properties
        VestingGroup storage group = vestingGroup[groupId];
        require(group.duration > 0, "SYB: This vesting group doesn't exist");
        require(
            group.supply + reward <= group.rewardCap,
            "SYB: Can't mint more than the group supply cap"
        );
        // Check if the vesting wallet is already created
        VestingWallet vestingWallet = investorVestingWallets[investor][groupId];
        if (address(vestingWallet) == address(0)) {
            // In the case the vesting wallet didn't exist before, create it and store it
            uint64 currentTimestamp = uint64(block.timestamp);
            vestingWallet = new VestingWallet(
                investor,
                currentTimestamp + group.delay,
                group.duration
            );
            investorVestingWallets[investor][groupId] = vestingWallet;
            // Add this group id for this investor
            investorToGroupIds[investor].push(groupId);
            // Emit the creation event
            emit VestingWalletCreated(
                investor,
                address(vestingWallet),
                currentTimestamp + group.delay,
                group.duration
            );
        }
        // Decrease the cap for this group
        group.supply += reward;
        vestingGroup[groupId] = group;
        // Emit the increase event
        emit VestingWalletSupplyIncreased(
            investor,
            address(vestingWallet),
            reward
        );
        // Mint the sybl token for this user
        sybelToken.mint(address(vestingWallet), reward);
    }

    /**
     * @dev Retrieve the vesting wallet for the given investor
     */
    function getVestingWallet(address investor)
        public
        view
        returns (VestingWallet[] memory)
    {
        uint8[] storage investorGroupIds = investorToGroupIds[investor];
        require(
            investorGroupIds.length > 0,
            "SYB: Not an investor in any groups"
        );
        // Build our initial vesting wallets map
        VestingWallet[] memory wallets = new VestingWallet[](
            investorGroupIds.length
        );
        // Find all the wallet for the user
        for (uint8 i = 0; i < investorGroupIds.length; ++i) {
            uint8 groupId = investorGroupIds[i];
            wallets[i] = investorVestingWallets[investor][groupId];
        }
        return wallets;
    }

    /**
     * @dev Retrieve the amount of token released for this investor
     */
    function releasedAmount(address investor) public view returns (uint256) {
        VestingWallet[] memory wallets = getVestingWallet(investor);
        uint256 currentReleased = 0;
        for (uint8 i = 0; i < wallets.length; ++i) {
            currentReleased += wallets[i].released(address(sybelToken));
        }
        return currentReleased;
    }

    /**
     * @dev Retlease all the token for the given investor
     */
    function release(address investor)
        external
        onlyRole(SybelRoles.ADMIN)
        whenNotPaused
    {
        VestingWallet[] memory wallets = getVestingWallet(investor);
        for (uint8 i = 0; i < wallets.length; ++i) {
            wallets[i].release(address(sybelToken));
        }
    }

    /**
     * @dev Retrieve the amount of token released for the calling wallet
     */
    function releasedAmount() external view returns (uint256) {
        return releasedAmount(msg.sender);
    }

    /**
     * @dev Release the token for the calling wallet
     */
    function release() external whenNotPaused {
        VestingWallet[] memory wallets = getVestingWallet(msg.sender);
        for (uint8 i = 0; i < wallets.length; ++i) {
            wallets[i].release(address(sybelToken));
        }
    }

    /**
     * @dev Represent the different vesting group
     */
    struct VestingGroup {
        uint256 rewardCap;
        uint256 supply;
        uint64 duration;
        uint64 delay;
    }
}
