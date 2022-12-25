// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "@frak/wallets/MultiVestingWallets.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";

/// Testing the frak l2 token
contract MultiVestingWalletsTest is PRBTest {
    ProxyTester proxy;

    FrakToken frakToken;
    MultiVestingWallets vestingWallets;

    address admin;

    function setUp() public {
        // Setup our proxy
        proxy = new ProxyTester();
        proxy.setType("uups");
        admin = vm.addr(69);

        // Deploy frak token
        address frkProxyAddr = proxy.deploy(address(new FrakToken()), admin);
        frakToken = FrakToken(frkProxyAddr);
        frakToken.initialize(address(this));

        // Deploy our multi vesting wallets
        address multiVestingAddr = proxy.deploy(address(new MultiVestingWallets()), admin);
        vestingWallets = MultiVestingWallets(multiVestingAddr);
        vestingWallets.initialize(address(frakToken));
    }

    /*
     * ===== TEST : initialize(address tokenAddr) =====
     */
    function testFailInitTwice() public {
        vestingWallets.initialize(address(0));
    }

    /*
     * ===== TEST : name() =====
     */
    function testName() public {
        assertEq(vestingWallets.name(), "Vested FRK Token");
    }

    /*
     * ===== TEST : decimals() =====
     */
    function testDecimals() public {
        assertEq(vestingWallets.decimals(), 18);
    }

    /*
     * ===== TEST : symbol() =====
     */
    function testSymbol() public {
        assertEq(vestingWallets.symbol(), "vFRK");
    }

    /*
     * ===== TEST : availableReserve() =====
     */
    function testAvailableReserve() public {
        assertEq(vestingWallets.availableReserve(), 0);
        frakToken.mint(address(vestingWallets), 1);
        assertEq(vestingWallets.availableReserve(), 1);
    }
}
