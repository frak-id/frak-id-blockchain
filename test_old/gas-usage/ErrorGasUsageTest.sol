// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { PRBTest } from "@prb/test/PRBTest.sol";

// Size : 50499
contract RevertWithString {
    // Gas used : 311
    function sample(uint256 amount) external pure {
        require(amount > 10, "Not enough amount");
    }
}

// Size : 40293
contract RevertWithError {
    error NotEnoughAmount();

    // Gas used : 260
    function sample(uint256 amount) external pure {
        if (amount < 10) revert NotEnoughAmount();
    }
}

// Size : 33087
contract RevertWithErrorAssembly {
    /// @dev 'bytes4(keccak256("NotEnoughAmount()"))'
    uint256 private constant _NOT_ENOUGH_AMOUNT_SELECTOR = 0xe008b5f9;

    // Gas used : 230
    function sample(uint256 amount) external pure {
        assembly {
            if lt(amount, 10) {
                mstore(0x00, _NOT_ENOUGH_AMOUNT_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }
}

/// Testing revert gas cost handling
contract ErrorGasUsageTest is PRBTest {
    RevertWithString testStringContract;

    RevertWithError testErrorContract;

    RevertWithErrorAssembly testErrorAssemblyContract;

    function setUp() public {
        testStringContract = new RevertWithString();
        testErrorContract = new RevertWithError();
        testErrorAssemblyContract = new RevertWithErrorAssembly();
    }

    function testFail_RevertWithString() public view {
        testStringContract.sample(1);
    }

    function testFail_RevertWithError() public view {
        testErrorContract.sample(1);
    }

    function testFail_RevertWithErrorAssembly() public view {
        testErrorAssemblyContract.sample(1);
    }
}
