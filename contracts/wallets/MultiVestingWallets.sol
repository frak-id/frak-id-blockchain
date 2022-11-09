// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../tokens/SybelTokenL2.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";

/// @dev error emitted when the contract doesn't have enough founds
error NotEnoughFounds();

/// @dev error throwned when verifying the input param
error InvalidDate();
error InvalidDuration();

/// @dev error throwned when a vesting doesn't exist
error InexistantVesting();

/// @dev error when we encounter a computation error
error ComputationError();

/// @dev error throwned when a vesting is not revocable, or when it already has been revoced
error VestingUnrevocable();
error VestingRevokedError();

contract MultiVestingWallets is SybelAccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    /// Emitted when a vesting is created
    event VestingCreated(
        uint24 indexed id,
        address indexed beneficiary,
        uint96 amount,
        uint96 initialDrop,
        uint32 duration,
        uint48 startDate
    );

    /// Emitted when a vesting is transfered between 2 address
    event VestingTransfered(uint24 indexed vestingId, address indexed from, address indexed to);

    /// Emitted when a vesting is revoked
    event VestingRevoked(uint24 indexed vestingId, address indexed beneficiary, uint96 refund);

    /// Emitted when a part of the vesting is released
    event VestingReleased(uint24 indexed vestingId, address indexed beneficiary, uint96 amount);

    /**
     * @dev Represent a vesting wallet
     */
    struct Vesting {
        // First storage slot, remain 6 bytes
        uint96 amount; // amount vested
        uint96 released; // amount already released
        uint32 duration; // duration of the vesting
        uint24 id; // id of the vesting
        bool isRevoked; // Is this vesting revoked ?
        bool isRevocable; // Is this vesting revocable ?
        // Second slot (remain 86 bytes)
        uint96 initialDrop; // initial drop when start date is reached
        uint48 startDate; // start date of this vesting
        // Third slot (full)
        address beneficiary; // beneficiary wallet of this vesting
    }

    /// Hard reward cap, of 200 million sybl
    uint96 private constant REWARD_CAP = 200_000_000 ether;

    /// Currently locked tokens that are being used by all of the vestings
    uint96 public totalSupply;

    /// Access to the sybel token
    IERC20Upgradeable private token;

    /// Current id of vesting
    uint24 private _idCounter;

    /// Vesting id to vesting
    mapping(uint256 => Vesting) public vestings;

    /// User to list of vesting id owned
    mapping(address => EnumerableSet.UintSet) private owned;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// Init our contract, with the sybel tokan and base role init
    function initialize(address tokenAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grand the vesting manager role to the owner
        _grantRole(SybelRoles.VESTING_MANAGER, msg.sender);

        // Init our sybel token
        token = IERC20Upgradeable(tokenAddr);
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token name.
     */
    function name() external pure returns (string memory) {
        return "Vested SYBL Token";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token symbol.
     */
    function symbol() external pure returns (string memory) {
        return "vSYBL";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the sybl's decimals value.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Get the available reserve.
     * @return The number of SYBL that can be used to create another vesting.
     */
    function availableReserve() public view returns (uint256) {
        return token.balanceOf(address(this)) - totalSupply;
    }

    /**
     * @notice Free the reserve up
     */
    function transferAvailableReserve(address receiver) external whenNotPaused onlyRole(SybelRoles.ADMIN) {
        uint256 available = availableReserve();
        if (available == 0) revert NoReward();
        token.safeTransfer(receiver, available);
    }

    /**
     * @notice Create a new vesting.
     */
    function createVest(
        address beneficiary,
        uint256 amount,
        uint256 initialDrop,
        uint32 duration,
        uint48 startDate,
        bool revocable
    ) external whenNotPaused onlyRole(SybelRoles.VESTING_MANAGER) {
        _requireVestInputs(duration, startDate);
        if (amount > availableReserve()) revert NotEnoughFounds();
        _createVesting(beneficiary, amount, initialDrop, duration, startDate, revocable);
    }

    /**
     * @notice Create multiple vesting at once.
     */
    function createVestBatch(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint256[] calldata initialDrops,
        uint32 duration,
        uint48 startDate,
        bool revocable
    ) external whenNotPaused onlyRole(SybelRoles.VESTING_MANAGER) {
        if (
            beneficiaries.length == 0 ||
            beneficiaries.length != amounts.length ||
            beneficiaries.length != initialDrops.length
        ) revert InvalidArray();
        _requireVestInputs(duration, startDate);

        uint256 freeReserve = availableReserve();

        for (uint256 index; index < beneficiaries.length; ) {
            uint256 amount = amounts[index];
            _createVesting(beneficiaries[index], amount, initialDrops[index], duration, startDate, revocable);
            if (amount > freeReserve) revert NotEnoughFounds();
            // Increment free reserve and counter
            unchecked {
                freeReserve -= amount;
                ++index;
            }
        }
    }

    /**
     * @notice Check the input when create a new vesting
     */
    function _requireVestInputs(uint32 duration, uint48 startDate) internal view {
        if (duration == 0) revert InvalidDuration();
        if (block.timestamp > startDate) revert InvalidDate();
    }

    /**
     * @notice Create a new vesting.
     */
    function _createVesting(
        address beneficiary,
        uint256 amount,
        uint256 initialDrop,
        uint32 duration,
        uint48 startDate,
        bool revocable
    ) private {
        if (beneficiary == address(0)) revert InvalidAddress();
        if (amount == 0) revert NoReward();
        if (amount > REWARD_CAP || initialDrop > amount) revert RewardTooLarge();

        // Create the vestings
        uint24 vestingId = _idCounter++;
        vestings[vestingId] = Vesting({
            amount: uint96(amount), // We can safely parse it since it don't increase the cap
            released: 0,
            duration: duration,
            id: vestingId,
            initialDrop: uint96(initialDrop), // Same here
            startDate: startDate,
            isRevoked: false,
            isRevocable: revocable,
            beneficiary: beneficiary
        });

        // Add the user the ownership, and increase the total supply
        _addOwnership(beneficiary, vestingId);
        unchecked {
            totalSupply += uint96(amount);
        }

        // Emit the creation and transfer event
        emit VestingCreated(vestingId, beneficiary, uint96(amount), uint96(initialDrop), duration, startDate);
        emit VestingTransfered(vestingId, address(0), beneficiary);
    }

    /**
     * @notice Transfer a vesting to another person.
     */
    function transfer(address to, uint24 vestingId) external onlyIfNotRevoked(vestingId) {
        if (to == address(0)) revert InvalidAddress();

        // Get the vesting
        Vesting storage vesting = _getVestingForBeneficiary(vestingId, msg.sender);
        address from = vesting.beneficiary;

        if (to == from) revert InvalidAddress();

        // Change the ownership of it
        _removeOwnership(from, vesting.id);
        _addOwnership(to, vesting.id);

        // And update the beneficiary
        vesting.beneficiary = to;

        // Then emit the event
        emit VestingTransfered(vestingId, from, to);
    }

    /**
     * @notice Release the tokens for the specified vesting.
     */
    function release(uint24 vestingId) external returns (uint256) {
        return _release(_getVestingForBeneficiary(vestingId, msg.sender));
    }

    /**
     * @notice Release the tokens of a all of sender's vesting.
     */
    function releaseAll() external returns (uint256) {
        return _releaseAll(msg.sender);
    }

    /**
     * @notice Release the tokens of a all of beneficiary's vesting.
     */
    function releaseAllFor(address beneficiary) external onlyRole(SybelRoles.VESTING_MANAGER) returns (uint256) {
        return _releaseAll(beneficiary);
    }

    /**
     * @dev Release the given vesting
     */
    function _release(Vesting storage vesting) internal whenNotPaused returns (uint256 released) {
        released = _doRelease(vesting);
        _checkAmount(released);
    }

    /**
     * @dev Release all the vestings from the given beneficiary
     */
    function _releaseAll(address beneficiary) internal whenNotPaused returns (uint256 released) {
        EnumerableSet.UintSet storage indexes = owned[beneficiary];

        for (uint256 index; index < indexes.length(); ) {
            uint24 vestingId = uint24(indexes.at(index));
            Vesting storage vesting = _getVesting(vestingId);

            released += _doRelease(vesting);

            unchecked {
                ++index;
            }
        }

        _checkAmount(released);
    }

    /**
     * @dev Releasing the given vesting, and returning the amount released
     */
    function _doRelease(Vesting storage vesting) internal returns (uint96 releasable) {
        releasable = _releasableAmount(vesting);

        if (releasable != 0) {
            // Update our state
            vesting.released += releasable;
            totalSupply -= releasable;

            // Then perform the transfer
            token.safeTransfer(vesting.beneficiary, releasable);
        }
    }

    /**
     * @dev Revert the transaction if the value is zero.
     */
    function _checkAmount(uint256 released) internal pure {
        if (released == 0) revert NoReward();
    }

    /**
     * @notice Get the releasable amount of tokens.
     * @param vestingId Vesting ID to check.
     * @return The releasable amounts.
     */
    function releasableAmount(uint24 vestingId) public view onlyIfNotRevoked(vestingId) returns (uint256) {
        return _releasableAmount(_getVesting(vestingId));
    }

    /**
     * @notice Get the vested amount of tokens.
     * @param vestingId Vesting ID to check.
     * @return The vested amount of the vestings.
     */
    function vestedAmount(uint24 vestingId) public view returns (uint256) {
        return _vestedAmount(_getVesting(vestingId));
    }

    /**
     * @notice Get the number of vesting for an address.
     * @param beneficiary Address to check.
     * @return The amount of vesting for the address.
     */
    function ownedCount(address beneficiary) public view returns (uint256) {
        return owned[beneficiary].length();
    }

    /**
     * @notice Get the remaining amount of token of a beneficiary.
     * @param beneficiary Address to check.
     * @return balance The remaining amount of tokens.
     */
    function balanceOf(address beneficiary) external view returns (uint256 balance) {
        uint256[] memory _vestingIds = owned[beneficiary].values();

        for (uint256 index; index < _vestingIds.length; ) {
            uint24 vestingId = uint24(_vestingIds[index]);
            balance += balanceOfVesting(vestingId);

            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice Get the remaining amount of token of a specified vesting.
     * @param vestingId Vesting ID to check.
     * @return The remaining amount of tokens.
     */
    function balanceOfVesting(uint24 vestingId) public view returns (uint256) {
        return _balanceOfVesting(_getVesting(vestingId));
    }

    /**
     * @notice Get the remaining amount of token of a specified vesting.
     * @param vesting Vesting to check.
     * @return The remaining amount of tokens.
     */
    function _balanceOfVesting(Vesting storage vesting) internal view returns (uint256) {
        return vesting.amount - vesting.released;
    }

    /**
     * @dev Compute the releasable amount.
     * @param vesting Vesting instance.
     */
    function _releasableAmount(Vesting storage vesting) internal view returns (uint96) {
        return _vestedAmount(vesting) - vesting.released;
    }

    /**
     * @dev Compute the vested amount.
     * @param vesting Vesting instance.
     */
    function _vestedAmount(Vesting storage vesting) internal view returns (uint96) {
        if (vesting.startDate == 0) {
            return 0;
        }

        uint64 vestingEnd = vesting.startDate + vesting.duration;
        if (block.timestamp < vesting.startDate) {
            // If not started yet, nothing can have been vested
            return 0;
        } else if (block.timestamp >= vestingEnd) {
            // If ended, all can be unlocked
            return vesting.amount;
        } else {
            // Otherwise, the proportionnal amount
            uint256 amountForVesting = ((vesting.amount - vesting.initialDrop) *
                (block.timestamp - vesting.startDate)) / vesting.duration;
            uint256 linearAmountComputed = amountForVesting + vesting.initialDrop;
            if (linearAmountComputed > REWARD_CAP) revert ComputationError(); // Ensure we are still on a uint96
            return uint96(linearAmountComputed);
        }
    }

    /**
     * @dev Get a vesting.
     * @return vesting struct stored in the storage.
     */
    function _getVesting(uint24 vestingId) internal view returns (Vesting storage vesting) {
        vesting = vestings[vestingId];
        if (vesting.beneficiary == address(0)) revert InexistantVesting();
    }

    /**
     * @dev Get a vesting and make sure it is from the right beneficiary.
     * @param beneficiary Address to get it from.
     * @return vesting struct stored in the storage.
     */
    function _getVestingForBeneficiary(uint24 vestingId, address beneficiary)
        internal
        view
        returns (Vesting storage vesting)
    {
        vesting = _getVesting(vestingId);
        if (vesting.beneficiary != beneficiary) revert NotAuthorized();
    }

    /**
     * @dev Remove the vesting from the ownership mapping.
     */
    function _removeOwnership(address account, uint24 vestingId) internal {
        owned[account].remove(vestingId);
    }

    /**
     * @dev Add the vesting ID to the ownership mapping.
     */
    function _addOwnership(address account, uint24 vestingId) internal {
        owned[account].add(vestingId);
    }

    /**
     * @notice Revoke a vesting wallet
     */
    function revoke(uint24 vestingId)
        external
        whenNotPaused
        onlyRole(SybelRoles.ADMIN)
        onlyIfNotRevoked(vestingId)
        returns (uint96 vestAmountRemaining)
    {
        // Get the vesting
        Vesting storage vesting = _getVesting(vestingId);
        if (!vesting.isRevocable) revert VestingUnrevocable();

        // Update the vesting state
        uint96 releasable = _releasableAmount(vesting);
        if (releasable != 0) {
            // Update our state
            vesting.released += releasable;
            totalSupply -= releasable;
        }
        vesting.isRevoked = true;

        // Compute the vest amount remaining
        vestAmountRemaining = vesting.amount - vesting.released;

        // Then perform the refund transfer if needed
        if (releasable != 0) {
            token.safeTransfer(vesting.beneficiary, releasable);
        }

        // Emit the event's
        emit VestingRevoked(vestingId, vesting.beneficiary, releasable);
        emit VestingTransfered(vestingId, vesting.beneficiary, address(0));
    }

    /**
     * @dev Revert if the start date is not zero.
     */
    modifier onlyIfNotRevoked(uint24 vestingId) {
        if (_getVesting(vestingId).isRevoked) revert VestingRevokedError();
        _;
    }
}
