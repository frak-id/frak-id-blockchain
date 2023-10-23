// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { Initializable } from "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @author @KONFeature
/// @title EIP712Diamond
/// @notice EIP712Diamond base contract with diamond storage
/// @custom:security-contact contact@frak.id
/// TODO: Use OZ5 -> Import another submodule based on OZ 5.0
contract EIP712Diamond {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The current version of the erc712, 2 since we switch between inline storage to diamond storage
    string internal constant ERC712_VERSION = "2";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The storage struct for eip 712
    struct EIP712Storage {
        /// @dev The current domain seperator
        bytes32 _domainSeperator;
        /// @dev Nonces per account
        mapping(address account => uint256 nonce) _nonces;
    }

    /// @dev Access the storage struct of the contract
    function _getEIP712Storage() internal pure returns (EIP712Storage storage $) {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("EIP712Diamond")) - 1)) & ~bytes32(uint256(0xff))
            $.slot := 0x8525956dfba681ee43bd6f7490f38cd4b2b234d15019aabbaf5a265041a3fb00
        }
    }

    /// @dev init function
    function _initializeEIP712(string memory name) internal {
        // Build and set the domain separator
        _getEIP712Storage()._domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public view methods                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Current domain seperator
    function getDomainSeperator() public view returns (bytes32) {
        return _getEIP712Storage()._domainSeperator;
    }

    /// @dev Get the current 'nonce' for the given 'user'
    function getNonce(address user) public view returns (uint256) {
        return _getEIP712Storage()._nonces[user];
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash) internal view returns (bytes32 digest) {
        bytes32 separator = _getEIP712Storage()._domainSeperator;
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, separator) // Store the domain separator.
            mstore(0x3a, messageHash) // Store the message hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /// @dev Use the current 'nonce' for the given 'user' (and increment it)
    function useNonce(address user) internal returns (uint256) {
        return _getEIP712Storage()._nonces[user]++;
    }
}
