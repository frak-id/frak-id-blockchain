// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { ERC20Upgradeable } from "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { InvalidSigner } from "../utils/FrakErrors.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { IFrakToken } from "./IFrakToken.sol";
import { EIP712Diamond } from "../utils/EIP712Diamond.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/// @author @KONFeature
/// @title FrakToken
/// @notice ERC20 Contract for the FRAK token
/// @dev Compliant with ERC20 - EIP712 - EIP2612
/// @custom:security-contact contact@frak.id
contract FrakToken is ERC20Upgradeable, FrakAccessControlUpgradeable, EIP712Diamond, IFrakToken {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Maximum cap of token, at 3 billion FRK
    uint256 private constant _cap = 3_000_000_000 ether;

    /* -------------------------------------------------------------------------- */
    /*                               Custom errors                                */
    /* -------------------------------------------------------------------------- */

    /// @dev Gap variable for the previous domain separator variable from the EIP712 Base contract
    bytes32 private _gapOldDomainSeparator;
    /// @dev Gap variable for the previous nonce variable from the EIP712 Base contract
    mapping(address => uint256) private _gapOldNonces;

    /// @dev 'bytes4(keccak256(bytes("PermitDelayExpired()")))'
    uint256 private constant _PERMIT_DELAYED_EXPIRED_SELECTOR = 0x95fc6e60;

    /// @dev 'bytes4(keccak256(bytes("InvalidSigner()")))'
    uint256 private constant _INVALID_SIGNER_SELECTOR = 0x815e1d64;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Versioning                                 */
    /* -------------------------------------------------------------------------- */

    function initialize() external initializer {
        string memory name = "Frak";
        __ERC20_init(name, "FRK");
        __FrakAccessControlUpgradeable_Minter_init();
        _initializeEIP712(name);

        // Current version is 2, since we use a version to reset the domain separator post EIP712 updates
    }

    /// @dev Update to diamond Eip712
    function updateToDiamondEip712() external reinitializer(3) {
        _initializeEIP712("FRK");
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write functions                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint some FRK
    function mint(address to, uint256 amount) external override onlyRole(FrakRoles.MINTER) {
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(to, amount);
    }

    /// @dev Burn some FRK
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    /// @dev Returns the cap on the token's total supply.
    function cap() external view virtual override returns (uint256) {
        return _cap;
    }

    /* -------------------------------------------------------------------------- */
    /*                 Permit logic (greatly inspired by solmate)                 */
    /* -------------------------------------------------------------------------- */

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
            address recoveredAddress = ECDSA.recover(
                toTypedMessageHash(
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            useNonce(owner),
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
