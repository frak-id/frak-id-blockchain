// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "@frak/wallets/MultiVestingWallets.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { UUPSTestHelper } from "../UUPSTestHelper.sol";

/// Testing the frak l2 token
contract MultiVestingWalletsTest is UUPSTestHelper {

    FrakToken frakToken;
    MultiVestingWallets vestingWallets;

    function setUp() public {
        // Deploy frak token
        address frkProxyAddr = deployContract(address(new FrakToken()));
        frakToken = FrakToken(frkProxyAddr);
        prankDeployer();
        frakToken.initialize(address(this));

        // Deploy our multi vesting wallets
        address multiVestingAddr = deployContract(address(new MultiVestingWallets()));
        vestingWallets = MultiVestingWallets(multiVestingAddr);
        prankDeployer();
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
        prankDeployer();
        frakToken.mint(address(vestingWallets), 1);
        assertEq(vestingWallets.availableReserve(), 1);
    }
}
