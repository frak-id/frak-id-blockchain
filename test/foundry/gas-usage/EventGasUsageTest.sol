// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {PRBTest} from "@prb/test/PRBTest.sol";

contract SampleEvent {
    event LogTransfer(address indexed from, address indexed to, uint256 value);

    function transfer(address to, uint256 value) public {
        emit LogTransfer(msg.sender, to, value);
    }
}

contract SampleAssemblyEvent {
    event LogTransfer(address indexed from, address indexed to, uint256 value);

    /// @dev 'keccak256("LogTransfer(address,address,uint256")'
    uint256 private constant _LOG_TRANSFER_SELECTOR = 0x3c70bac155b1df6b781842a200c9369a387d8d24e7cb6fafecba18a53e2de32b;

    function transfer(address to, uint256 value) public {
        assembly {
            mstore(0, value)
            log3(0x00, 0x20, _LOG_TRANSFER_SELECTOR, caller(), to)
        }
    }
}

/// Testing is event gas cost
contract EventGasUsageTest is PRBTest {
    SampleEvent sampleEvent;

    SampleAssemblyEvent sampleAssemblyEvent;

    function setUp() public {
        sampleEvent = new SampleEvent();
        sampleAssemblyEvent = new SampleAssemblyEvent();
    }

    event Test(bytes32 selector);

    function test_event() public {
        sampleEvent.transfer(address(1), 10);
    }

    function test_eventAssembly() public {
        sampleAssemblyEvent.transfer(address(1), 10);
    }
}
