// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { IFrakToken } from "../tokens/IFrakToken.sol";
import { FraktionTokens } from "../fraktions/FraktionTokens.sol";
import { IPushPullReward } from "../utils/IPushPullReward.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title WalletMigrator
/// @notice Wallet migrator, used to migrate wallet from one to another
/// @custom:security-contact contact@frak.id
contract WalletMigrator is Multicallable {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                  Storages                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Our frak and fraktions tokens
    IFrakToken private immutable frkToken;
    FraktionTokens private immutable fraktionTokens;

    /// @dev Our different reward pools
    IPushPullReward private immutable rewarderPool;
    IPushPullReward private immutable contentPool;
    IPushPullReward private immutable referralPool;

    /// @dev Create this wallet migrator, with all the addresses
    constructor(
        address _frkToken,
        address _fraktionTokens,
        address _rewarder,
        address _contentPool,
        address _referralPool
    ) {
        // Set our tokens
        frkToken = IFrakToken(_frkToken);
        fraktionTokens = FraktionTokens(_fraktionTokens);

        // Set our reward pools
        rewarderPool = IPushPullReward(_rewarder);
        contentPool = IPushPullReward(_contentPool);
        referralPool = IPushPullReward(_referralPool);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Claim functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Claim all the founds for a user at once
    function claimAllFounds() public {
        _claimAllFounds(msg.sender);
    }

    /// @dev Claim all the founds for a user at once
    function claimAllFoundsForUser(address user) public {
        _claimAllFounds(user);
    }

    /// @dev Claim all the founds for a user at once
    function _claimAllFounds(address user) internal {
        rewarderPool.withdrawFounds(user);
        contentPool.withdrawFounds(user);
        referralPool.withdrawFounds(user);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Frak migration functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Migrate all the FRK of the current user to the `newWallet`
    function migrateFrk(address newWallet, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        _migrateFrk(msg.sender, newWallet, deadline, v, r, s);
    }

    /// @dev Migrate all the FRK of the current user to the `newWallet`
    function migrateFrkForUser(
        address user,
        address newWallet,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        _migrateFrk(user, newWallet, deadline, v, r, s);
    }

    /// @dev Migrate all the FRK of the current user to the `newWallet`
    function migrateFrkForUserDirect(address user, address newWallet) external {
        address(frkToken).safeTransferFrom(user, newWallet, frkToken.balanceOf(user));
    }

    /// @dev Migrate all the frk of the `user` to the `newWallet`, using EIP-2612 signature as approval
    function _migrateFrk(address user, address newWallet, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
        // We use the signature to allow the transfer all the FRK of the user
        frkToken.permit(user, address(this), type(uint256).max, deadline, v, r, s);

        // And finally, we transfer all the FRK of the user to the new wallet
        address(frkToken).safeTransferFrom(user, newWallet, frkToken.balanceOf(user));
    }

    /* -------------------------------------------------------------------------- */
    /*                        Fraktions migration functions                       */
    /* -------------------------------------------------------------------------- */

    /// @dev Migrate all the fraktions to the `newWallet`at once
    function migrateFraktions(
        address newWallet,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256[] calldata ids
    )
        external
    {
        _migrateFraktions(msg.sender, newWallet, deadline, v, r, s, ids);
    }

    /// @dev Migrate all the fraktions to the `newWallet`at once
    function migrateFraktionsForUser(
        address user,
        address newWallet,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256[] calldata ids
    )
        external
    {
        _migrateFraktions(user, newWallet, deadline, v, r, s, ids);
    }

    /// @dev Migrate all the fraktions to the `newWallet`at once
    function migrateFraktionsForUserDirect(address user, address newWallet, uint256[] calldata ids) external {
        // And finally, we transfer all the FRK of the user to the new wallet
        fraktionTokens.transferAllFrom(user, newWallet, ids);
    }

    /// @dev Migrate all the fraktions to the `newWallet`at once
    function _migrateFraktions(
        address user,
        address newWallet,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256[] calldata ids
    )
        internal
    {
        // We use the signature to allow the transfer all the FRK of the user
        fraktionTokens.permitAllTransfer(user, address(this), deadline, v, r, s);

        // And finally, we transfer all the FRK of the user to the new wallet
        fraktionTokens.transferAllFrom(user, newWallet, ids);
    }
}
