// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, PermitDelayExpired, InvalidSigner } from "contracts/utils/FrakErrors.sol";
import { FrakToken } from "contracts/tokens/FrakToken.sol";
import { IFrakToken } from "contracts/tokens/IFrakToken.sol";

/// @dev Testing custom methods on the FrakToken
contract FrakTokenTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeWithSelector(FrakToken.initialize.selector);
        address proxyAddress = _deployProxy(address(new FrakToken()), initData, "FrakTokenDeploy");
        frakToken = FrakToken(proxyAddress);

        // Can be updated
        bytes memory updateData = bytes.concat(FrakToken.updateToDiamondEip712.selector);
        frakToken.upgradeToAndCall(address(new FrakToken()), updateData);
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

    function test_mint_CapExceed_ko() public asDeployer {
        // Single shot exceed
        vm.expectRevert(IFrakToken.CapExceed.selector);
        frakToken.mint(user, 3_000_000_001 ether);

        // Multiple mint then exceed
        frakToken.mint(user, 1_000_000_000 ether);
        frakToken.mint(user, 1_000_000_000 ether);
        frakToken.mint(user, 1_000_000_000 ether);
        vm.expectRevert(IFrakToken.CapExceed.selector);
        frakToken.mint(user, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Permit tests                                */
    /* -------------------------------------------------------------------------- */

    function test_permit_ok() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(contentOwner, 1 ether, block.timestamp);

        // Perform the permit op & ensure it's valid
        frakToken.permit(user, contentOwner, 1 ether, block.timestamp, v, r, s);

        assertEq(frakToken.allowance(user, contentOwner), 1 ether);
    }

    function test_permit_DelayExpired_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(contentOwner, 1 ether, block.timestamp - 1);

        // Perform the permit op & ensure it's valid
        vm.expectRevert(PermitDelayExpired.selector);
        frakToken.permit(user, contentOwner, 1 ether, block.timestamp - 1, v, r, s);
    }

    function test_permit_InvalidSigner_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(contentOwner, 1 ether, block.timestamp);

        // Perform the permit op & ensure it's valid
        vm.expectRevert(InvalidSigner.selector);
        frakToken.permit(address(1), contentOwner, 1 ether, block.timestamp, v, r, s);
    }

    function test_permit_InvalidNonce_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            userPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    frakToken.getDomainSeperator(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, user, contentOwner, 1 ether, 12_345, block.timestamp))
                )
            )
        );

        // Perform the permit op & ensure it's valid
        vm.expectRevert(InvalidSigner.selector);
        frakToken.permit(address(1), contentOwner, 1 ether, block.timestamp, v, r, s);
    }

    /* -------------------------------------------------------------------------- */
    /*                           A few invariant's test                           */
    /* -------------------------------------------------------------------------- */

    function invariant_cap_lt_supply() public {
        assertGt(frakToken.cap(), frakToken.totalSupply());
    }
}
