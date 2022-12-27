// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { FrakToken, CapExceed } from "@frak/tokens/FrakTokenL2.sol";
import { NotAuthorized } from "@frak/utils/FrakErrors.sol";
import { UUPSTestHelper } from "../UUPSTestHelper.sol";

/// Testing the frak l2 token
contract FrkTokenL2Test is UUPSTestHelper {
    FrakToken frakToken;

    function setUp() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(FrakToken.initialize, (address(this)));
        address proxyAddress = deployContract(address(new FrakToken()), initData);
        frakToken = FrakToken(proxyAddress);
    }

    /*
     * ===== TEST : initialize(address childChainManager) =====
     */
    function test_fail_initialize_CantInitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        frakToken.initialize(address(0));
    }

    /*
     * ===== TEST : name() =====
     */
    function test_name() public {
        assertEq(frakToken.name(), "Frak");
    }

    /*
     * ===== TEST : decimals() =====
     */
    function test_decimals() public {
        assertEq(frakToken.decimals(), 18);
    }

    /*
     * ===== TEST : symbol() =====
     */
    function test_symbol() public {
        assertEq(frakToken.symbol(), "FRK");
    }

    /*
     * ===== TEST : totalSupply() =====
     */
    function test_totalSupply() public {
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
    function test_balanceOf() public {
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
    function test_transfer() public {
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

    function testFuzz_transfer(address target, uint256 amount) public {
        vm.assume(target != address(0));
        vm.assume(amount < 3_000_000_000 ether);

        prankDeployer();
        frakToken.mint(address(1), amount);

        vm.prank(address(1));
        frakToken.transfer(target, amount);
        assertEq(frakToken.balanceOf(target), amount);
        assertEq(frakToken.balanceOf(address(1)), 0);
    }

    function test_fail_transfer_NotEnoughBalance() public {
        prankDeployer();
        frakToken.mint(address(1), 10);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(address(1));
        frakToken.transfer(address(2), 15);
    }

    function test_fail_transfer_InvalidAddress() public {
        prankDeployer();
        frakToken.mint(address(1), 10);

        vm.expectRevert("ERC20: transfer to the zero address");
        vm.prank(address(1));
        frakToken.transfer(address(0), 5);
    }

    /*
     * ===== TEST : approve(address spender, uint256 amount) =====
     * ===== TEST : allowance(address owner, address spender) =====
     * ===== TEST : addedValue(address owner, uint256 addedValue) =====
     * ===== TEST : decreaseAllowance(address owner, uint256 subtractedValue) =====
     */
    function test_approve_increase_decrease() public {
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

    function test_fail_approve_InvalidAddress() public {
        vm.expectRevert("ERC20: approve to the zero address");
        frakToken.approve(address(0), 100);
    }

    function test_fail_increaseAllowance_InvalidAddress() public {
        vm.expectRevert("ERC20: approve to the zero address");
        frakToken.increaseAllowance(address(0), 100);
    }

    function test_fail_decreaseAllowance_BelowZero() public {
        vm.expectRevert("ERC20: decreased allowance below zero");
        frakToken.decreaseAllowance(address(1), 100);
    }

    /*
     * ===== TEST : transferFrom(address from, address to, uint256 amount) =====
     */
    function test_transferFrom(uint256 amount) public {
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
    function test_fail_mint_NotMinter() public {
        vm.expectRevert(NotAuthorized.selector);
        frakToken.mint(address(1), 1 ether);
    }

    function test_fail_mint_Addr0() public prankExecAsDeployer {
        vm.expectRevert("ERC20: mint to the zero address");
        frakToken.mint(address(0), 1 ether);
    }

    function test_fail_mint_TooLarge() public prankExecAsDeployer {
        vm.expectRevert(CapExceed.selector);
        frakToken.mint(address(1), 3_000_000_001 ether);
    }

    function testFuzz_mint(uint256 mintAmount) public prankExecAsDeployer {
        vm.assume(mintAmount < 3_000_000_000 ether);
        frakToken.mint(address(1), mintAmount);
        assertEq(frakToken.balanceOf(address(1)), mintAmount);
    }
}
