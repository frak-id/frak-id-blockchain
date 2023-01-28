// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {FrakToken} from "../tokens/FrakTokenL2.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {InvalidAddress, RewardTooLarge, NoReward} from "../utils/FrakErrors.sol";

/// Error thrown when the contract havn't enough found to perform the withdraw
error NotEnoughTreasury();

contract FrakTreasuryWallet is MintingAccessControlUpgradeable {
    using SafeERC20Upgradeable for FrakToken;

    // The cap of frk token for the treasury
    uint256 internal constant FRK_MINTING_CAP = 330_000_000 ether;

    /// The cap at which we will re-mint some token to this contract
    uint256 internal constant FRK_MAX_TRANSFER = 500_000 ether;

    /// The number of token we will mint when the cap is reached
    uint256 internal constant FRK_MINTING_AMOUNT = 1_000_000 ether;

    // The total amount of frak minted for the treasury
    uint256 public totalFrakMinted;

    /**
     * @dev Access our token
     */
    FrakToken private frakToken;

    /**
     * @dev Event emitted when the treasury is filled with a few frk token
     */
    event TreasuryFilled(uint256 mintedAmount);

    /**
     * @dev Event emitted when the treasury transfer some token
     */
    event TreasuryTransfer(address indexed target, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address frkTokenAddr) external initializer {
        if (frkTokenAddr == address(0)) revert InvalidAddress();

        __MintingAccessControlUpgradeable_init();

        frakToken = FrakToken(frkTokenAddr);
    }

    /**
     * @dev Transfer the given number of token to the user
     */
    function transfer(address target, uint256 amount) external whenNotPaused onlyRole(FrakRoles.MINTER) {
        // Ensure param are valid
        if (target == address(0)) revert InvalidAddress();
        if (amount > FRK_MAX_TRANSFER) revert RewardTooLarge();
        if (amount == 0) revert NoReward();

        // Ensure we got enough founds, and if not, try to mint more and ensure we minted enough
        uint256 currentBalance = frakToken.balanceOf(address(this));
        if (amount > currentBalance) {
            uint256 mintedAmount = _mintNewToken();
            if (amount > currentBalance + mintedAmount) revert NotEnoughTreasury();
        }

        // Once we are good, move the token to the given address
        emit TreasuryTransfer(target, amount);
        frakToken.safeTransfer(target, amount);
    }

    /**
     * @dev Mint some fresh token to this contract, and return the number of token minted
     */
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
