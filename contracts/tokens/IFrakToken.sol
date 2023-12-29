// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { IERC20Upgradeable } from "@oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @author @KONFeature
/// @title IFrakToken
/// @notice Interface for the FrakToken
/// @custom:security-contact contact@frak.id
interface IFrakToken is IERC20Upgradeable {
    /// @dev error throwned when the contract cap is exceeded
    error CapExceed();

    /// @dev Mint `amount` of FRK to `to`
    function mint(address to, uint256 amount) external;

    /// @dev Burn `amount` of FRK
    function burn(uint256 amount) external;

    /// @dev Returns the cap on the token's total supply.
    function cap() external view returns (uint256);

    /// @dev EIP 2612, allow the owner to spend the given amount of FRK
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        payable;
}
