// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { UUPSTestHelper } from "../UUPSTestHelper.sol";

/// Testing the frak l2 token
contract FrkTokenL2Test is UUPSTestHelper {

    FrakToken frakToken;

    function setUp() public {

        // Deploy our contract via proxy and set the proxy address
        address proxyAddress = deployContract(address(new FrakToken()));
        frakToken = FrakToken(proxyAddress);
        prankDeployer();
        frakToken.initialize(address(this));
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

        prankDeployer();
        frakToken.mint(address(1), 1);
        assertEq(frakToken.totalSupply(), 1);

        vm.prank(address(1));
        frakToken.burn(1);
        assertEq(frakToken.totalSupply(), 0);
    }

    /*
     * ===== TEST : balanceOf(address account) =====
     */
    function testBalanceOf() public {
        assertEq(frakToken.balanceOf(address(1)), 0);

        prankDeployer();
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
        prankDeployer();
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

        prankDeployer();
        frakToken.mint(address(1), amount);

        vm.prank(address(1));
        frakToken.transfer(target, amount);
        assertEq(frakToken.balanceOf(target), amount);
        assertEq(frakToken.balanceOf(address(1)), 0);
    }

    function testFailTransferNotEnoughBalance() public {
        prankDeployer();
        frakToken.mint(address(1), 10);

        vm.prank(address(1));
        frakToken.transfer(address(2), 15);
    }

    function testFailTransferInvalidAddress() public {
        prankDeployer();
        frakToken.mint(address(1), 10);

        vm.prank(address(1));
        frakToken.transfer(address(0), 5);
    }

    /*
     * ===== TEST : approve(address spender, uint256 amount) =====
     * ===== TEST : allowance(address owner, address spender) =====
     * ===== TEST : addedValue(address owner, uint256 addedValue) =====
     * ===== TEST : decreaseAllowance(address owner, uint256 subtractedValue) =====
     */
    function testApproveOkIncreaseOkDecreaseOk() public {
        uint256 allowance = frakToken.allowance(address(this), address(1));
        assertEq(allowance, 0);

        frakToken.approve(address(1), 100);
        allowance = frakToken.allowance(address(this), address(1));
        assertEq(allowance, 100);

        frakToken.increaseAllowance(address(1), 50);
        allowance = frakToken.allowance(address(this), address(1));
        assertEq(allowance, 150);

        frakToken.decreaseAllowance(address(1), 50);
        allowance = frakToken.allowance(address(this), address(1));
        assertEq(allowance, 100);
    }

    function testFailApproveInvalidAddress() public {
        frakToken.approve(address(0), 100);
    }

    function testFailIncreaseAllowanceInvalidAddress() public {
        frakToken.increaseAllowance(address(0), 100);
    }

    function testFailDecreaseAllowanceInvalidAddress() public {
        frakToken.decreaseAllowance(address(0), 100);
    }

    /*
     * ===== TEST : transferFrom(address from, address to, uint256 amount) =====
     */
    function testTransferFromOk(uint256 amount) public {
        vm.assume(amount < 3_000_000_000 ether);
        prankDeployer();
        frakToken.mint(address(1), amount);

        vm.prank(address(1));
        frakToken.approve(address(2), amount);

        vm.prank(address(2));
        frakToken.transferFrom(address(1), address(3), amount);
        assertEq(frakToken.balanceOf(address(3)), amount);
    }

    /*
     * ===== TEST : mint(address to, uint256 amount) =====
     */
    function testFailMintNotMinter() public {
        frakToken.mint(address(1), 1 ether);
    }

    function testFailMintAddr0() public prankExecAsDeployer {
        frakToken.mint(address(0), 1 ether);
    }

    function testFailMintTooLarge() public prankExecAsDeployer {
        frakToken.mint(address(1), 3_000_000_001 ether);
    }

    function testMintOkForOwnerFuzz(uint256 mintAmount) public prankExecAsDeployer {
        vm.assume(mintAmount < 3_000_000_000 ether);
        frakToken.mint(address(1), mintAmount);
        assertEq(frakToken.balanceOf(address(1)), mintAmount);
    }
}
