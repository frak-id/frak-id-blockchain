// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../../contracts/tokens/FrakTokenL2.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";

// TODO : Should switch to PrbTest
contract FrkTokenL2Test is PRBTest {

    ProxyTester proxy;

    FrakToken initialImpl;
    FrakToken frakToken;

    address proxyAddress;

    address admin;

    function setUp() public {
        // Deploy initial token
        initialImpl = new FrakToken();

        // Deploy our proxy
        proxy = new ProxyTester();
        proxy.setType("uups");
        admin = vm.addr(69);

        // Deploy our contract via proxy and set the proxy address
        proxyAddress = proxy.deploy(address(initialImpl), admin);
        frakToken = FrakToken(proxyAddress);
    }

    function testProxyIsSameAddr() public {
        // Assert proxy address is a valid addr
        assertEq(proxyAddress, proxy.proxyAddress());
        assertEq(proxyAddress, address(proxy.uups()));
        // And ensure it's not the same as the frak tken
        assertNotEq(proxyAddress, address(initialImpl));
    }

    function testFailMintAddr0() public {
        frakToken.mint(address(0), 1 ether);
    }

    function testFailMint0amount() public {
        frakToken.mint(address(1), 0);
    }

    function testFailMintCapExceeded() public {
        frakToken.mint(address(1), 3_000_000_001 ether);
    }

    function testMintOk() public {
        frakToken.mint(address(1), 3_000 ether);
    }

}