// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../tokens/SybelToken.sol";
import "../utils/SybelAccessControlUpgradeable.sol";
import "../utils/SybelRoles.sol";
import "hardhat/console.sol";

contract MultiVestingWallets is SybelAccessControlUpgradeable {
    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    /// Emitted when  the vesting begin
    event VestingBegin(uint64 startDate);

    /// Emitted when a vesting is created
    event VestingCreated(
        uint256 indexed vestingId,
        address indexed beneficiary,
        uint256 amount,
        uint64 delay,
        uint64 duration
    );

    /// Emitted when a vesting is transfered between 2 address
    event VestingTransfered(
        uint256 indexed vestingId,
        address indexed from,
        address indexed to
    );

    /**
     * @dev Represent a vesting wallet
     */
    struct Vesting {
        uint256 id;
        address beneficiary;
        uint256 amount;
        uint64 delay; // Delay before start of the vesting
        uint64 duration;
        uint256 released; // Amount of token released
    }

    /// Vesting id to vesting
    mapping(uint256 => Vesting) public vestings;

    /// User to list of vesting id owned
    mapping(address => EnumerableSet.UintSet) private owned;

    /// Currently locked tokens that are being used by all of the vestings
    uint256 public totalSupply;

    /// Access to the sybel token
    SybelToken private sybelToken;

    /// Starting date for the vesting wallets
    uint64 public startDate;

    /// Current id of vesting
    uint256 private _idCounter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// Init our contract, with the sybel tokan and base role init
    function initialize(address sybelTokenAddr) external initializer {
        __SybelAccessControlUpgradeable_init();

        // Grand the vesting manager role to the owner
        _grantRole(SybelRoles.VESTING_MANAGER, msg.sender);

        // Init our sybel token
        sybelToken = SybelToken(sybelTokenAddr);
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token name.
     */

    function name() external pure returns (string memory) {
        return "Vested SYBL Token (multi)";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the contract 'fake' token symbol.
     */
    function symbol() external pure returns (string memory) {
        return "mvSYBL";
    }

    /**
     * @notice Fake an ERC20-like contract allowing it to be displayed from wallets.
     * @return the sybl's decimals value.
     */
    function decimals() external view returns (uint8) {
        return sybelToken.decimals();
    }

    /**
     * @notice Get the current reserve (or balance) of the contract in SYBL.
     * @return The balance of SYBL this contract has.
     */
    function reserve() public view returns (uint256) {
        return sybelToken.balanceOf(address(this));
    }

    /**
     * @notice Get the available reserve.
     * @return The number of SYBL that can be used to create another vesting.
     */
    function availableReserve() public view returns (uint256) {
        return reserve() - totalSupply;
    }

    /**
     * @notice Begin the vesting of everyone at the current block timestamp.
     */
    function beginNow() external {
        _begin(uint64(block.timestamp));
    }

    /**
     * @notice Begin the vesting of everyone at a specified timestamp.
     * @param timestamp Timestamp to use as a begin date.
     */
    function beginAt(uint64 timestamp) external {
        require(timestamp != 0, "SYB: start timestamp cannot be zero");
        require(timestamp > block.timestamp, "SYB: Can't start the vesting for a prior date");
        _begin(timestamp);
    }

    /**
     * @notice Begin the vesting for everyone at the given timestamp.
     */
    function _begin(uint64 timestamp) internal whenNotPaused onlyWhenNotStarted onlyRole(SybelRoles.VESTING_MANAGER) {
        startDate = timestamp;
        emit VestingBegin(timestamp);
    }

    /**
     * @notice Create a new vesting.
     */
    function createVest(
        address beneficiary,
        uint256 amount,
        uint64 delay,
        uint64 duration
    ) external whenNotPaused onlyWhenNotStarted onlyRole(SybelRoles.VESTING_MANAGER) {
        _requireVestInputs(delay, duration);
        _createVesting(beneficiary, amount, delay, duration);
    }

    /**
     * @notice Create multiple vesting at once.
     */
    function createVestBatch(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint64 delay,
        uint64 duration
    ) external whenNotPaused onlyWhenNotStarted onlyRole(SybelRoles.VESTING_MANAGER) {
        require(beneficiaries.length > 0, "SYB: No beneficiaries given");
        require(beneficiaries.length == amounts.length, "SYB: Invalid array lengths");
        _requireVestInputs(delay, duration);

        for (uint256 index = 0; index < beneficiaries.length; ++index) {
            _createVesting(beneficiaries[index], amounts[index], delay, duration);
        }
    }

    /**
     * @notice Check the input when create a new vesting
     */
    function _requireVestInputs(uint64 delay, uint64 duration) internal pure {
        require((duration + delay) > 0, "SYB: Duration + delay should be greater than 0");
    }

    /**
     * @notice Create a new vesting.
     */
    function _createVesting(
        address beneficiary,
        uint256 amount,
        uint64 delay,
        uint64 duration
    ) internal {
        require(beneficiary != address(0), "SYB: Can't vest on the 0 address");
        require(amount > 0, "SYB: amount need to be > 0");
        require(availableReserve() >= amount, "SYB: Doesn't have enough founds");

        // Create the vestings
        uint256 vestingId = _idCounter++;
        vestings[vestingId] = Vesting({
            id: vestingId,
            beneficiary: beneficiary,
            amount: amount,
            delay: delay,
            duration: duration,
            released: 0
        });

        // Add the user the ownership, and increase the total supply
        bool isAdded = _addOwnership(beneficiary, vestingId);
        require(isAdded, "SYB: Unable to add the vesting");
        totalSupply += amount;

        // Emit the creation and transfer event
        emit VestingCreated(vestingId, beneficiary, amount, delay, duration);
        emit VestingTransfered(vestingId, address(0), beneficiary);
    }

    /**
     * @notice Transfer a vesting to another person.
     */
    function transfer(address to, uint256 vestingId) external {
        require(to != address(0), "SYB: target is the zero address");

        // Get the vesting
        Vesting storage vesting = _getVestingForBeneficiary(vestingId, _msgSender());
        address from = vesting.beneficiary;

        require(from != to, "SYB: cannot transfer to itself");

        // Change the ownership of it
        bool isRemoved = _removeOwnership(from, vesting.id);
        require(isRemoved, "SYB: Unable to remove the ownership of the vesting");
        bool isAdded = _addOwnership(to, vesting.id);
        require(isAdded, "SYB: Unable to add the ownership of the vesting");

        // And update the beneficiary
        vesting.beneficiary = to;

        // Then emit the event
        emit VestingTransfered(vestingId, from, to);
    }

    /**
     * @notice Release the tokens for the specified vesting.
     */
    function release(uint256 vestingId) external returns (uint256) {
        return _release(_getVestingForBeneficiary(vestingId, _msgSender()));
    }

    /**
     * @notice Release the tokens of a all of sender's vesting.
     */
    function releaseAll() external returns (uint256) {
        return _releaseAll(_msgSender());
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
    function _release(Vesting storage vesting) internal whenNotPaused onlyWhenStarted returns (uint256 released) {
        released = _doRelease(vesting);
        _checkAmount(released);
    }

    /**
     * @dev Release all the vestings from the given beneficiary
     */
    function _releaseAll(address beneficiary) internal whenNotPaused onlyWhenStarted returns (uint256 released) {
        EnumerableSet.UintSet storage indexes = owned[beneficiary];

        for (uint256 index = 0; index < indexes.length(); ++index) {
            uint256 vestingId = indexes.at(index);
            Vesting storage vesting = vestings[vestingId];

            released += _doRelease(vesting);
        }

        _checkAmount(released);
    }

    /**
     * @dev Releasing the given vesting, and returning the amount released
     */
    function _doRelease(Vesting storage vesting) internal returns (uint256 releasable) {
        releasable = _releasableAmount(vesting);

        if (releasable != 0) {
            // Update our state
            vesting.released += releasable;
            totalSupply -= releasable;

            // Then perform the transfer
            sybelToken.transfer(vesting.beneficiary, releasable);
        }
    }

    /**
     * @dev Revert the transaction if the value is zero.
     */
    function _checkAmount(uint256 released) internal pure {
        require(released > 0, "SYB: no tokens are due");
    }

    /**
     * @notice Get the releasable amount of tokens.
     * @param vestingId Vesting ID to check.
     * @return The releasable amounts.
     */
    function releasableAmount(uint256 vestingId) public view returns (uint256) {
        return _releasableAmount(_getVesting(vestingId));
    }

    /**
     * @notice Get the vested amount of tokens.
     * @param vestingId Vesting ID to check.
     * @return The vested amount of the vestings.
     */
    function vestedAmount(uint256 vestingId) public view returns (uint256) {
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
        EnumerableSet.UintSet storage indexes = owned[beneficiary];

        for (uint256 index = 0; index < indexes.length(); ++index) {
            uint256 vestingId = indexes.at(index);

            balance += balanceOfVesting(vestingId);
        }
    }

    /**
     * @notice Get the remaining amount of token of a specified vesting.
     * @param vestingId Vesting ID to check.
     * @return The remaining amount of tokens.
     */
    function balanceOfVesting(uint256 vestingId) public view returns (uint256) {
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
    function _releasableAmount(Vesting storage vesting) internal view returns (uint256) {
        return _vestedAmount(vesting) - vesting.released;
    }

    /**
     * @dev Compute the vested amount.
     * @param vesting Vesting instance.
     */
    function _vestedAmount(Vesting storage vesting) internal view returns (uint256) {
        if (startDate == 0) {
            return 0;
        }

        uint64 cliffEnd = startDate + vesting.delay;
        if (block.timestamp < cliffEnd) {
            // If not started yet, nothing can have been vested
            return 0;
        } else if (block.timestamp >= cliffEnd + vesting.duration) {
            // If ended, all can be unlocked
            return vesting.amount;
        } else {
            // Otherwise, the proportionnal amount
            return (vesting.amount * (block.timestamp - cliffEnd)) / vesting.duration;
        }
    }

    /**
     * @dev Get a vesting.
     * @return vesting struct stored in the storage.
     */
    function _getVesting(uint256 vestingId) internal view returns (Vesting storage vesting) {
        vesting = vestings[vestingId];
        require(vesting.beneficiary != address(0), "SYB: Vesting does not exists");
    }

    /**
     * @dev Get a vesting and make sure it is from the right beneficiary.
     * @param beneficiary Address to get it from.
     * @return vesting struct stored in the storage.
     */
    function _getVestingForBeneficiary(uint256 vestingId, address beneficiary)
        internal
        view
        returns (Vesting storage vesting)
    {
        vesting = _getVesting(vestingId);
        require(vesting.beneficiary == beneficiary, "SYB: Not the vesting beneficiary");
    }

    /**
     * @dev Remove the vesting from the ownership mapping.
     */
    function _removeOwnership(address account, uint256 vestingId) internal returns (bool isRemoved) {
        isRemoved = owned[account].remove(vestingId);
    }

    /**
     * @dev Add the vesting ID to the ownership mapping.
     */
    function _addOwnership(address account, uint256 vestingId) internal returns (bool isAdded) {
        isAdded = owned[account].add(vestingId);
    }

    /**
     * @dev Revert if the start date is not zero.
     */
    modifier onlyWhenNotStarted() {
        require(startDate == 0, "SYB: already started");
        _;
    }

    /**
     * @dev Revert if the start date is zero.
     */
    modifier onlyWhenStarted() {
        require(startDate != 0, "SYB: not started");
        _;
    }
}
