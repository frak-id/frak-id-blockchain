// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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
        keccak256(bytes("EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)"));

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    bytes32 internal domainSeperator;

    /// @dev init function
    function _initializeEIP712(string memory name) internal onlyInitializing {
        _setDomainSeperator(name);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public view method                             */
    /* -------------------------------------------------------------------------- */

    function getDomainSeperator() internal view returns (bytes32) {
        return domainSeperator;
    }

    function getChainId() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
        return id;
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
                address(this),
                bytes32(getChainId())
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
    function toTypedMessageHash(bytes32 messageHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeperator, messageHash));
    }
}
