// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { IFrakToken } from "../tokens/IFrakToken.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { InvalidAddress, RewardTooLarge, NoReward } from "../utils/FrakErrors.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// Error thrown when the contract havn't enough found to perform the withdraw
error NotEnoughTreasury();

/// @author @KONFeature
/// @title FrakTreasuryWallet
/// @notice This contract is used to store some frk token for the treasury
/// @custom:security-contact contact@frak.id
contract FrakTreasuryWallet is FrakAccessControlUpgradeable, Multicallable {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    // The cap of frk token for the treasury
    uint256 internal constant FRK_MINTING_CAP = 330_000_000 ether;

    /// The cap at which we will re-mint some token to this contract
    uint256 internal constant FRK_MAX_TRANSFER = 500_000 ether;

    /// The number of token we will mint when the cap is reached
    uint256 internal constant FRK_MINTING_AMOUNT = 1_000_000 ether;

    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("NoReward()")))'
    uint256 private constant _NO_REWARD_SELECTOR = 0x6e992686;

    /// @dev 'bytes4(keccak256(bytes("InvalidArray()")))'
    uint256 private constant _INVALID_ARRAY_SELECTOR = 0x1ec5aa51;

    /// @dev 'bytes4(keccak256(bytes("RewardTooLarge()")))'
    uint256 private constant _REWARD_TOO_LARGE_SELECTOR = 0x71009bf7;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Event emitted when the treasury is filled with a few frk token
     */
    event TreasuryFilled(uint256 mintedAmount);

    /**
     * @dev Event emitted when the treasury transfer some token
     */
    event TreasuryTransfer(address indexed target, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The total amount of frak minted for the treasury
    uint256 private totalFrakMinted;

    /// @dev Access our token
    IFrakToken private frakToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token) external initializer {
        if (_token == address(0)) revert InvalidAddress();

        __FrakAccessControlUpgradeable_Minter_init();

        frakToken = IFrakToken(_token);
    }

    /// @dev Transfer `amount` of token to `target`
    function transfer(address target, uint256 amount) external onlyRole(FrakRoles.MINTER) {
        assembly {
            // Ensure the param are valid and not too much
            if iszero(target) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            if iszero(amount) {
                mstore(0x00, _NO_REWARD_SELECTOR)
                revert(0x1c, 0x04)
            }
            if gt(amount, FRK_MAX_TRANSFER) {
                mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Ensure we got enough founds, and if not, try to mint more and ensure we minted enough
        uint256 currentBalance = address(frakToken).balanceOf(address(this));
        if (amount > currentBalance) {
            uint256 mintedAmount = _mintNewToken();
            if (amount > currentBalance + mintedAmount) {
                revert NotEnoughTreasury();
            }
        }

        // Once we are good, move the token to the given address
        emit TreasuryTransfer(target, amount);
        address(frakToken).safeTransfer(target, amount);
    }

    /// @dev Transfer all `amounts` to each `targets`
    function transferBatch(
        address[] calldata targets,
        uint256[] calldata amounts
    )
        external
        onlyRole(FrakRoles.MINTER)
    {
        assembly {
            // Ensure we got valid data
            if or(iszero(eq(targets.length, amounts.length)), iszero(targets.length)) {
                mstore(0x00, _INVALID_ARRAY_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Get the length to iterate through
        uint256 length = targets.length;

        // Get the current balance
        uint256 currentBalance = address(frakToken).balanceOf(address(this));

        for (uint256 i; i < length;) {
            // Extract params
            address target = targets[i];
            uint256 amount = amounts[i];

            assembly {
                // Ensure the param are valid and not too much
                if iszero(target) {
                    mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                    revert(0x1c, 0x04)
                }
                if iszero(amount) {
                    mstore(0x00, _NO_REWARD_SELECTOR)
                    revert(0x1c, 0x04)
                }
                if gt(amount, FRK_MAX_TRANSFER) {
                    mstore(0x00, _REWARD_TOO_LARGE_SELECTOR)
                    revert(0x1c, 0x04)
                }
            }

            // Ensure we don't exceed the balance (otherwise, mint new tokens)
            if (amount > currentBalance) {
                uint256 mintedAmount = _mintNewToken();
                // Update the current balance
                currentBalance += mintedAmount;

                // Ensure we got enought balance
                if (amount > currentBalance) revert NotEnoughTreasury();
            }

            // Once we are good, move the token to the given address, and decrease the total balance
            currentBalance -= amount;
            emit TreasuryTransfer(target, amount);
            address(frakToken).safeTransfer(target, amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Mint some fresh token to this contract, and return the number of token minted
    function _mintNewToken() private returns (uint256 amountToMint) {
        if (totalFrakMinted + FRK_MINTING_AMOUNT < FRK_MINTING_CAP) {
            // In the case we have enough room, mint 1m token directly
            amountToMint = FRK_MINTING_AMOUNT;
        } else {
            // Otherwise, check the minting room we got, and mint that amount if needed
            amountToMint = FRK_MINTING_CAP - totalFrakMinted;
        }

        // If we got something to mint, increase our frak minted and mint the frk tokens
        if (amountToMint > 0) {
            totalFrakMinted += amountToMint;
            emit TreasuryFilled(amountToMint);
            frakToken.mint(address(this), amountToMint);
        }
    }
}
