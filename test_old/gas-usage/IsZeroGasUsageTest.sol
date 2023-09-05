// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { PRBTest } from "@prb/test/PRBTest.sol";

contract IsZero {
    function sample(address addr) external pure returns (bool) {
        return addr == address(0);
    }
}

contract IsZeroAssembly {
    function sample(address addr) external pure returns (bool) {
        assembly {
            if iszero(addr) { return(0x20, 32) }

            mstore(0x20, 1)
            return(0x00, 32)
        }
    }
}

/// Testing is zero gas cost handling
contract IsZeroGasUsageTest is PRBTest {
    IsZero isZeroContract;

    IsZeroAssembly isZeroAssemblyContract;

    function setUp() public {
        isZeroContract = new IsZero();
        isZeroAssemblyContract = new IsZeroAssembly();
    }

    function test_isZero() public view {
        isZeroContract.sample(address(123));
        // isZeroContract.sample(address(0));
    }

    function test_isZeroAssembly() public view {
        isZeroAssemblyContract.sample(address(123));
        // isZeroAssemblyContract.sample(address(0));
    }
}
