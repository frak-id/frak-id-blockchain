// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../../contracts/tokens/FrakTokenL2.sol";
import "./utils/UUPSProxy.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";

// TODO : Should switch to PrbTest
contract FrkTokenL2Test is PRBTest {

    FrakToken frakToken;
    UUPSProxy proxy;

    function setUp() public {
        FrakToken initialFrakToken = new FrakToken();
        proxy = new UUPSProxy(address(initialFrakToken), "");
        frakToken = FrakToken(address(proxy));
    }

    function testProxyIsSameAddr() public {
        assertEq(address(frakToken), address(proxy));
    }

}