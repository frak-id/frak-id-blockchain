// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import {EnumerableSet} from "openzeppelin/utils/structs/EnumerableSet.sol";
import {SafeERC20Upgradeable} from "@oz-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {FrakAccessControlUpgradeable} from "../utils/FrakAccessControlUpgradeable.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {NotAuthorized, InvalidArray, InvalidAddress, NoReward, RewardTooLarge} from "../utils/FrakErrors.sol";

/// @dev error emitted when the contract doesn't have enough founds
error NotEnoughFounds();

/// @dev error throwned when verifying the input param
error InvalidDate();
error InvalidDuration();

/// @dev error throwned when a vesting doesn't exist
error InexistantVesting();

/// @dev error when we encounter a computation error
error ComputationError();

contract MultiVestingWallets is FrakAccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    /// Emitted when a vesting is created
    event VestingCreated(
        uint24 indexed id, address indexed beneficiary, uint96 amount, uint32 duration, uint48 startDate
    );

    /// Emitted when a vesting is transfered between 2 address
    event VestingTransfered(uint24 indexed vestingId, address indexed from, address indexed to);

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
        // Second slot (remain 86 bytes)
        uint48 startDate; // start date of this vesting
        // Third slot (full)
        address beneficiary; // beneficiary wallet of this vesting
    }

    /// Hard reward cap, of 200 million frk
    uint96 private constant REWARD_CAP = 200_000_000 ether;

    /// Max possible timestamp at the 13 january 2050
    uint256 private constant MAX_TIMESTAMP = 2_525_644_800;

    /// Currently locked tokens that are being used by all of the vestings
    uint96 public totalSupply;

    /// Access to the frak token
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

    /// Init our contract, with the frak tokan and base role init
    function initialize(address tokenAddr) external initializer {
        if (tokenAddr == address(0)) revert InvalidAddress();

        __FrakAccessControlUpgradeable_init();

        // Grand the vesting manager role to the owner
        _grantRole(FrakRoles.VESTING_MANAGER, msg.sender);

        // Init our frak token
        token = IERC20Upgradeable(tokenAddr);
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token name.
     */
    function name() external pure returns (string memory) {
        return "Vested FRK Token";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token symbol.
     */
    function symbol() external pure returns (string memory) {
        return "vFRK";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the frk's decimals value.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Get the available reserve.
     * @return The number of FRK that can be used to create another vesting.
     */
    function availableReserve() public view returns (uint256) {
        return token.balanceOf(address(this)) - totalSupply;
    }

    /**
     * @notice Free the reserve up
     */
    function transferAvailableReserve(address receiver) external whenNotPaused onlyRole(FrakRoles.ADMIN) {
        uint256 available = availableReserve();
        if (available == 0) revert NoReward();
        token.safeTransfer(receiver, available);
    }

    /**
     * @notice Create a new vesting.
     */
    function createVest(address beneficiary, uint256 amount, uint32 duration, uint48 startDate)
        external
        whenNotPaused
        onlyRole(FrakRoles.VESTING_MANAGER)
    {
        _requireVestInputs(duration, startDate);
        if (amount > availableReserve()) revert NotEnoughFounds();
        _createVesting(beneficiary, amount, duration, startDate);
    }

    /**
     * @notice Create multiple vesting at once.
     */
    function createVestBatch(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint32 duration,
        uint48 startDate
    ) external whenNotPaused onlyRole(FrakRoles.VESTING_MANAGER) {
        if (beneficiaries.length == 0 || beneficiaries.length != amounts.length) {
            revert InvalidArray();
        }
        _requireVestInputs(duration, startDate);

        uint256 freeReserve = availableReserve();

        for (uint256 index; index < beneficiaries.length;) {
            uint256 amount = amounts[index];
            if (amount > freeReserve) revert NotEnoughFounds();
            _createVesting(beneficiaries[index], amount, duration, startDate);
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
        if (block.timestamp > startDate || startDate > MAX_TIMESTAMP) {
            revert InvalidDate();
        }
    }

    /**
     * @notice Create a new vesting.
     */
    function _createVesting(address beneficiary, uint256 amount, uint32 duration, uint48 startDate) private {
        if (beneficiary == address(0)) revert InvalidAddress();
        if (amount == 0) revert NoReward();
        if (amount > REWARD_CAP) revert RewardTooLarge();

        // Create the vestings
        uint24 vestingId = _idCounter++;
        vestings[vestingId] = Vesting({
            amount: uint96(amount), // We can safely parse it since it don't increase the cap
            released: 0,
            duration: duration,
            id: vestingId,
            startDate: startDate,
            beneficiary: beneficiary
        });

        // Add the user the ownership, and increase the total supply
        _addOwnership(beneficiary, vestingId);
        unchecked {
            totalSupply += uint96(amount);
        }

        // Emit the creation and transfer event
        emit VestingCreated(vestingId, beneficiary, uint96(amount), duration, startDate);
        emit VestingTransfered(vestingId, address(0), beneficiary);
    }

    /**
     * @notice Transfer a vesting to another person.
     */
    function transfer(address to, uint24 vestingId) external {
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
    function releaseAllFor(address beneficiary) external onlyRole(FrakRoles.VESTING_MANAGER) returns (uint256) {
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

        for (uint256 index; index < indexes.length();) {
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

            /// Emitted when a part of the vesting is released
            emit VestingReleased(vesting.id, vesting.beneficiary, releasable);

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
    function releasableAmount(uint24 vestingId) public view returns (uint256) {
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

        for (uint256 index; index < _vestingIds.length;) {
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
            uint256 amountForVesting = (vesting.amount * (block.timestamp - vesting.startDate)) / vesting.duration;
            if (amountForVesting > REWARD_CAP) revert ComputationError();
            // Ensure we are still on a uint96
            return uint96(amountForVesting);
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
     * @dev Update a vesting start date
     */
    function fixVestingDate(uint24[] calldata vestingIds) external onlyRole(FrakRoles.VESTING_MANAGER) {
        for (uint256 index = 0; index < vestingIds.length; index++) {
            // Get the vesting
            uint24 vestingId = vestingIds[index];
            Vesting memory vesting = _getVesting(vestingId);

            // Check is date on update it if needed
            if (vesting.startDate > MAX_TIMESTAMP) {
                uint48 newDate = vesting.startDate / 1000;
                // If that's good, update the date
                if (newDate > block.timestamp && newDate < MAX_TIMESTAMP) {
                    vestings[vestingId].startDate = newDate;
                }
            }
        }
    }
}
