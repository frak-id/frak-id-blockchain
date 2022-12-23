// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";

/// Testing the frak l2 token
contract FrkTokenL2Test is PRBTest {

    ProxyTester proxy;

    FrakToken initialImpl;
    FrakToken frakToken;

    address admin;

    function setUp() public {
        // Deploy initial token
        initialImpl = new FrakToken();

        // Deploy our proxy
        proxy = new ProxyTester();
        proxy.setType("uups");
        admin = vm.addr(69);

        // Deploy our contract via proxy and set the proxy address
        address proxyAddress = proxy.deploy(address(initialImpl), admin);
        frakToken = FrakToken(proxyAddress);
        frakToken.initialize(address(this));
    }

    function testProxyIsSameAddr() public {
        // Assert proxy address is a valid addr
        assertEq(address(frakToken), proxy.proxyAddress());
        assertEq(address(frakToken), address(proxy.uups()));
        // And ensure it's not the same as the frak tken
        assertNotEq(address(frakToken), address(initialImpl));
    }

    /*
     * ===== TEST : initialize(address childChainManager) =====
     */
    function testFailInitTwice() public {
        frakToken.initialize(address(0));
    }

    /*
     * ===== TEST : name() =====
     */
    function testName() public {
        assertEq(frakToken.name(), "Frak");
    }

    /*
     * ===== TEST : decimals() =====
     */
    function testDecimals() public {
        assertEq(frakToken.decimals(), 18);
    }

    /*
     * ===== TEST : symbol() =====
     */
    function testSymbol() public {
        assertEq(frakToken.symbol(), "FRK");
    }

    /*
     * ===== TEST : totalSupply() =====
     */
    function testTotalSupply() public {
        assertEq(frakToken.totalSupply(), 0);
        frakToken.mint(address(this), 1);
        assertEq(frakToken.totalSupply(), 1);
        frakToken.burn(1);
        assertEq(frakToken.totalSupply(), 0);
    }

    /*
     * ===== TEST : balanceOf(address account) =====
     */
    function testBalanceOf() public {
        assertEq(frakToken.balanceOf(address(1)), 0);
        frakToken.mint(address(1), 1);
        assertEq(frakToken.balanceOf(address(1)), 1);
        vm.prank(address(1));
        frakToken.burn(1);
        assertEq(frakToken.balanceOf(address(1)), 0);
    }

    /*
     * ===== TEST : transfer(address to, uint256 amount) =====
     */
    function testTransferOk() public {
        frakToken.mint(address(1), 10);

        vm.prank(address(1));
        frakToken.transfer(address(2), 5);
        assertEq(frakToken.balanceOf(address(2)), 5);
        assertEq(frakToken.balanceOf(address(1)), 5);

        vm.prank(address(1));
        frakToken.transfer(address(2), 5);
        assertEq(frakToken.balanceOf(address(2)), 10);
        assertEq(frakToken.balanceOf(address(1)), 0);
    }

    function testTransferOkFuzz(address target, uint256 amount) public {
        vm.assume(target != address(0));
        vm.assume(amount < 3_000_000_000 ether);

        frakToken.mint(address(1), amount);

        vm.prank(address(1));
        frakToken.transfer(target, amount);
        assertEq(frakToken.balanceOf(target), amount);
        assertEq(frakToken.balanceOf(address(1)), 0);
    }

    function testFailTransferNotEnoughBalance() public {
        frakToken.mint(address(1), 10);

        vm.prank(address(1));
        frakToken.transfer(address(2), 15);
    }

    function testFailTransferInvalidAddress() public {
        frakToken.mint(address(1), 10);

        vm.prank(address(1));
        frakToken.transfer(address(0), 5);
    }

    /*
     * ===== TEST : mint(address to, uint256 amount) =====
     */
    function testFailMintAddr0() public {
        frakToken.mint(address(0), 1 ether);
    }

    function testFailMintTooLarge() public {
        frakToken.mint(address(1), 3_000_000_001 ether);
    }

    function testFailMintNotOwner() public {
        vm.prank(address(1));
        frakToken.mint(address(1), 3_000 ether);
    }

    function testMintOkForOwnerFuzz(uint256 mintAmount) public {
        vm.assume(mintAmount < 3_000_000_000 ether);
        frakToken.mint(address(1), mintAmount);
        assertEq(frakToken.balanceOf(address(1)), mintAmount);
    }
}