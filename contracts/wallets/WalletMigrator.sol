// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

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
    /*                         Public migration functions                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Claim all the founds for a user at once
    function claimAllFounds() public {
        _claimAllFounds(msg.sender);
    }

    /// @dev Migrate all the FRK of the current user to the `newWallet`
    function migrateFrk(address newWallet, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        // We use the signature to allow the transfer all the FRK of the user
        frkToken.permit(msg.sender, address(this), type(uint256).max, deadline, v, r, s);

        // And finally, we transfer all the FRK of the user to the new wallet
        address(frkToken).safeTransferFrom(msg.sender, newWallet, frkToken.balanceOf(msg.sender));
    }

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
        // We use the signature to allow the transfer all the FRK of the user
        fraktionTokens.permitAllTransfer(msg.sender, address(this), deadline, v, r, s);

        // And finally, we transfer all the FRK of the user to the new wallet
        fraktionTokens.transferAllFrom(msg.sender, newWallet, ids);
    }

    /// @dev Send all the matic of the sender to the `newWallet`
    function migrateMatic(address newWallet) external {
        newWallet.safeTransferAllETH();
    }

    /* -------------------------------------------------------------------------- */
    /*                        Internal migration functions                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Claim all the founds for a user at once
    function _claimAllFounds(address user) internal {
        rewarderPool.withdrawFounds(user);
        contentPool.withdrawFounds(user);
        referralPool.withdrawFounds(user);
    }
}
