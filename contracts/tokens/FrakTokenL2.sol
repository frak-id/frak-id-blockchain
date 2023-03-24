// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {ContextMixin} from "../utils/ContextMixin.sol";
import {IFrakToken} from "./IFrakToken.sol";
import {EIP712Base} from "../utils/EIP712Base.sol";

/**
 * @author  @KONFeature
 * @title   FrakToken
 * @dev  ERC20 Contract for the FRAK token
 * @notice Compliant with ERC20 - EIP712 - EIP2612
 * @custom:security-contact contact@frak.id
 */
contract FrakToken is
    ERC20Upgradeable,
    MintingAccessControlUpgradeable,
    EIP712Base,
    ContextMixin,
    IFrakToken
{

    /* -------------------------------------------------------------------------- */
    /*                                 Constant's                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Role used by the polygon bridge to bridge token between L1 <-> L2
    bytes32 internal constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /// @dev Maximum cap of token, at 3 billion FRK
    uint256 private constant _cap = 3_000_000_000 ether;

    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev error throwned when the signer is invalid
    error InvalidSigner();

    /// @dev error throwned when the contract cap is exceeded
    error CapExceed();

    /// @dev error throwned when the permit delay is expired
    error PermitDelayExpired();

    /// @dev 'bytes4(keccak256(bytes("PermitDelayExpired()")))'
    uint256 private constant _PERMIT_DELAYED_EXPIRED_SELECTOR = 0x95fc6e60;

    /// @dev 'bytes4(keccak256(bytes("InvalidSigner()")))'
    uint256 private constant _INVALID_SIGNER_SELECTOR = 0x815e1d64;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

    function initialize(address childChainManager) external initializer {
        string memory name = "Frak";
        __ERC20_init(name, "FRK");
        __MintingAccessControlUpgradeable_init();
        _initializeEIP712(name);

        _grantRole(DEPOSITOR_ROLE, childChainManager);

        // Current version is 2, since we use a version to reset the domain separator post EIP712 updates
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }

    /// @dev Mint some FRK
    function mint(address to, uint256 amount) external override onlyRole(FrakRoles.MINTER) whenNotPaused {
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(to, amount);
    }

    /// @dev Burn some FRK
    function burn(uint256 amount) external override whenNotPaused {
        _burn(_msgSender(), amount);
    }

    /// @dev Returns the cap on the token's total supply.
    function cap() external view virtual override returns (uint256) {
        return _cap;
    }

    /* -------------------------------------------------------------------------- */
    /*                 Permit logic (greatly inspired by solmate)                 */
    /* -------------------------------------------------------------------------- */

    /// @dev EIP 2612, allow the owner to spend the given amount of FRK
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        override
    {
        assembly {
            if gt(timestamp(), deadline) {
                mstore(0x00, _PERMIT_DELAYED_EXPIRED_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                toTypedMessageHash(
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                ),
                v,
                r,
                s
            );

            // Don't need to check for 0 address, or send event's, since approve already do it for us
            if (recoveredAddress != owner) revert InvalidSigner();

            // Approve the token
            _approve(recoveredAddress, spender, value);
        }
    }
}
