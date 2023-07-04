// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.20;

import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";

contract EIP712Base is Initializable {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constant's                                 */
    /* -------------------------------------------------------------------------- */

    string internal constant ERC712_VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The current domain seperator
    bytes32 internal domainSeperator;

    /// @dev Nonces per user
    mapping(address => uint256) internal nonces;

    /// @dev init function
    function _initializeEIP712(string memory name) internal onlyInitializing {
        _setDomainSeperator(name);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public view method                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Current domain seperator
    function getDomainSeperator() public view returns (bytes32) {
        return domainSeperator;
    }

    /// @dev Get the current 'nonce' for the given 'user'
    function getNonce(address user) external view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal function's                            */
    /* -------------------------------------------------------------------------- */

    function _setDomainSeperator(string memory name) internal {
        domainSeperator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(ERC712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * Accept message hash and returns hash message in EIP712 compatible form
     * So that it can be used to recover signer from signature signed using EIP712 formatted data
     * https://eips.ethereum.org/EIPS/eip-712
     * "\\x19" makes the encoding deterministic
     * "\\x01" is the version byte to make it compatible to EIP-191
     */
    function toTypedMessageHash(bytes32 messageHash) internal view returns (bytes32 digest) {
        bytes32 separator = domainSeperator;
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
}
