// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./MultiVestingWallets.sol";
import "../tokens/SybelToken.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

contract VestingWalletFactory is SybelAccessControlUpgradeable {

    // Perform safe transfer
    using SafeERC20Upgradeable for SybelToken;

    // The cap of sybl token propose to vester
    uint96 internal constant SYBL_VESTING_CAP = 1_500_000_000 ether;

    /**
     * @dev Represent the different vesting group
     */
    struct VestingGroup {
        // First storage slot (full)
        uint96 rewardCap;
        uint96 supply;
        uint32 duration;
        uint32 delay;

        // Second storage slot (only useing 17 bytes on 256 available)
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
    event GroupAdded(uint8 indexed id, uint96 rewardCap, uint16 initialDropPerthousand, uint32 duration, uint32 delay);
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
        uint32 delay,
        bool revocable
    ) external onlyRole(SybelRoles.ADMIN) {
        _addVestingGroup(id, rewardCap, initialDropPerthousand, duration, delay, revocable);
    }

    /**
     * @dev Add a new vesting group
     */
    function _addVestingGroup(
        uint8 id,
        uint96 rewardCap,
        uint16 initialDropPerthousand,
        uint32 duration,
        uint32 delay,
        bool revocable
    ) private whenNotPaused {
        require(vestingGroup[id].rewardCap == 0, "SYB: This vesting group already exist");
        require(rewardCap > 0, "SYB: The reward cap should be superior to 0");
        require(duration > 0, "SYB: The duration should be superior to 0");
        require(rewardCap + totalGroupCap <= SYBL_VESTING_CAP, "SYB: Reward cap exceeding total cap for vesting");
        // Increase the total group supply
        totalGroupCap += rewardCap;
        // Build and save this group
        vestingGroup[id] = VestingGroup({
            rewardCap : rewardCap, 
            supply : 0, 
            duration: duration, 
            delay: delay,
            initialDropPerthousand: initialDropPerthousand,
            isRevocable: revocable
        });
        // Emit the event
        emit GroupAdded(id, rewardCap, initialDropPerthousand, duration, delay);
    }

    /**
     * @notice Transfer a group reserve to another one
     */
    function transferGroupReserve(uint8 initialId, uint8 targetId, uint96 amount) external whenNotPaused onlyRole(SybelRoles.ADMIN) {
        // Ensure the group as enough supply
        VestingGroup storage initialGroup = _getVestingGroup(initialId);
        require(initialGroup.rewardCap - amount >= initialGroup.supply, "SYB: Not enought group supply");
        VestingGroup storage targetGroup = _getVestingGroup(targetId);

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
        return _getVestingGroup(id);
    }

    /**
     * @dev Get the group for the given id
     */
    function _getVestingGroup(uint8 id) private view returns (VestingGroup storage group) {
        group = vestingGroup[id];
        require(group.rewardCap > 0, "SYB: Group doesn't exist");
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
        require(reward!= 0, "SYBL : Reward shouldn't 0");
        require(reward< SYBL_VESTING_CAP, "SYBL : Reward too large"); // Ensure the reward pass in a uint96 also
        require(beneficiary != address(0), "SYB: Wrong investor address");
        // Find the group and check basic properties
        VestingGroup storage group = _getVestingGroup(groupId);
        require(group.supply + reward <= group.rewardCap, "SYB: Reward too big");
        // Compute the initial drop if needed
        uint256 initialDrop = 0;
        if(group.initialDropPerthousand > 0) {
            initialDrop = (reward * group.initialDropPerthousand) / 1000;
        }
        // Update the group supply
        group.supply += uint96(reward);

        // Check the balance of this contract
        uint256 currentBalance = sybelToken.balanceOf(address(this));

        // Mint the sybl token for this user
        sybelToken.mint(address(multiVestingWallets), reward - currentBalance);

        // Transfer the token already owned by this contract (if any, in case of revoked vest)
        if(currentBalance > 0) {
            sybelToken.safeTransfer(address(multiVestingWallets), currentBalance);
        }

        // Create the vesting group
        multiVestingWallets.createVest(beneficiary, reward, initialDrop, group.delay, group.duration, startDate, group.isRevocable);

        // Emit the event
        emit GroupUserAdded(groupId, beneficiary, uint96(reward));
    }

    /**
     * @notice Revoke a user vest wallet, and so reduce the group supply by the amount unlocked
     */
    function revokeUserVest(uint8 groupId, uint24 vestId) external onlyRole(SybelRoles.VESTING_CREATOR) whenNotPaused  {
        // Get our group and the previous sybl balance of the contract
        VestingGroup storage group = _getVestingGroup(groupId);

        // Perform the vest release
        uint96 remainingAmount = multiVestingWallets.revoke(vestId);

        // Decrement the supply of the released amount
        group.supply -= remainingAmount;
    }
}
