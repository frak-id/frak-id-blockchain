// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {PRBTest} from "@prb/test/PRBTest.sol";

// Deployment cost : 116_565
contract SolidityLoop {
    // value : [13, 12, 1337] Gas used : 1_546
    function sample(uint256[] calldata values) external pure returns (uint256[] memory transformed) {
        unchecked {
            transformed = new uint256[](values.length);
            for (uint256 i = 0; i < values.length; i++) {}
        }
    }
}

// Deployment cost : 79_929
contract AssemblyRegularForLoop {
    // value : [13, 12, 1337] Gas used : 1_211
    function sample(uint256[] calldata values) external pure returns (uint256[] memory transformed) {
        assembly {
            // Get the free mem pointer and allocate it to the transformed array
            transformed := mload(0x40)
            // Store the array length
            mstore(transformed, values.length)
            // Initial transformed offset
            let transformedOffset := add(transformed, 0x20)
            // Update free mem pointer
            mstore(0x40, add(transformedOffset, shl(5, values.length)))

            for { let i := 0 } lt(i, values.length) { i := add(i, 1) } {
                // Load value from calldata
                let value := calldataload(add(values.offset, mul(i, 0x20)))
                // Build transformed value
                let newTransformed := or(shl(4, value), 3)
                // Store it
                mstore(add(transformedOffset, shl(5, i)), newTransformed)
            }
        }
    }
}

// Deployment cost : 77_129
contract AssemblyInfiniteForLoop {
    // value : [13, 12, 1337] Gas used : 1_113
    function sample(uint256[] calldata values) external pure returns (uint256[] memory transformed) {
        assembly {
            // Get the free mem pointer and allocate it to the transformed array
            transformed := mload(0x40)
            // Store the array length
            mstore(transformed, values.length)
            // Initial transformed and values offset
            let valuesOffset := values.offset
            let transformedOffset := add(transformed, 0x20)
            // Check where we should end
            let valuesEnd := add(valuesOffset, shl(5, values.length))

            // Infinite loop
            for {} 1 {} {
                // Load value from calldata
                let value := calldataload(valuesOffset)
                // Build transformed value
                let newTransformed := or(shl(4, value), 3)
                // Store it
                mstore(transformedOffset, newTransformed)
                // Increase each iterator
                valuesOffset := add(valuesOffset, 0x20)
                transformedOffset := add(transformedOffset, 0x20)
                // Exit if we reached the end of our values array
                if iszero(lt(valuesOffset, valuesEnd)) { break }
            }

            // Update free mem pointer
            mstore(0x40, transformedOffset)
        }
    }
}

/// Testing loop gas usage
contract LoopUsageTest is PRBTest {
    AssemblyInfiniteForLoop testLoop;

    uint256[] private testValues = [13, 12, 1337];

    function setUp() public {
        testLoop = new AssemblyInfiniteForLoop();
    }

    function test() public view {
        testLoop.sample(testValues);
    }
}
