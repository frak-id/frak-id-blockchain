// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized } from "contracts/utils/FrakErrors.sol";

/// @dev Testing custom methods on the FrkToken
contract FrakTokenTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        frakToken.initialize();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Some global properties test                        */
    /* -------------------------------------------------------------------------- */

    function test_name_ok() public {
        assertEq(frakToken.name(), "Frak");
    }

    function test_decimals_ok() public {
        assertEq(frakToken.decimals(), 18);
    }

    function test_symbol_ok() public {
        assertEq(frakToken.symbol(), "FRK");
    }

    function test_cap_ok() public {
        assertEq(frakToken.cap(), 3_000_000_000 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Burn & mint's test                             */
    /* -------------------------------------------------------------------------- */

    function test_mint_ok() public asDeployer {
        frakToken.mint(user, 1);
        assertEq(frakToken.balanceOf(user), 1);
    }

    function test_burn_ok() public withFrk(user, 1) {
        vm.prank(user);
        frakToken.burn(1);
        assertEq(frakToken.balanceOf(user), 0);
    }

    function test_mint_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        frakToken.mint(user, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                           A few invariant's test                           */
    /* -------------------------------------------------------------------------- */

    function invariant_cap_lt_supply() public {
        assertGt(frakToken.cap(), frakToken.totalSupply());
    }
}
