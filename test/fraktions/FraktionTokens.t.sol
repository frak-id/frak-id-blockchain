// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidArray, InvalidSigner, PermitDelayExpired } from "contracts/utils/FrakErrors.sol";
import { FraktionTokens } from "contracts/fraktions/FraktionTokens.sol";
import { FraktionTransferCallback } from "contracts/fraktions/FraktionTransferCallback.sol";
import { ContentId, ContentIdLib } from "contracts/libs/ContentId.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";

/// @dev Testing custom methods on the FraktionTokens
contract FraktionTokensTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("https://metadata/url"));
        address proxyAddress = _deployProxy(address(new FraktionTokens()), initData, "FraktionTokensDeploy");
        fraktionTokens = FraktionTokens(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        fraktionTokens.initialize("https://metadata/url");
    }

    /* -------------------------------------------------------------------------- */
    /*                            Content related test                            */
    /* -------------------------------------------------------------------------- */

    function test_addContent_ok() public asDeployer {
        uint256[] memory suppliesToType = _getMintContentParams();
        ContentId contentId = fraktionTokens.mintNewContent(contentOwner, suppliesToType);

        // Ensure the content is well created, with valid supply
        assertEq(fraktionTokens.ownerOf(contentId), contentOwner);
        assertEq(fraktionTokens.supplyOf(contentId.commonFraktionId()), 100);
        assertEq(fraktionTokens.supplyOf(contentId.premiumFraktionId()), 50);
        assertEq(fraktionTokens.supplyOf(contentId.goldFraktionId()), 25);
        assertEq(fraktionTokens.supplyOf(contentId.diamondFraktionId()), 10);

        // Ensure that two content id are not the same
        ContentId newContentId = fraktionTokens.mintNewContent(contentOwner, suppliesToType);
        assertNotEq(ContentId.unwrap(contentId), ContentId.unwrap(newContentId));
    }

    function test_addContent_InvalidRole_ko() public {
        uint256[] memory suppliesToType = _getMintContentParams();

        vm.expectRevert(NotAuthorized.selector);
        fraktionTokens.mintNewContent(contentOwner, suppliesToType);
    }

    function test_addContent_SupplyUpdateNotAllowed_ko() public asDeployer {
        uint256[] memory suppliesToType = _getMintContentParams();

        suppliesToType[0] = 0;
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.mintNewContent(contentOwner, suppliesToType);

        suppliesToType[0] = 1;
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.mintNewContent(contentOwner, suppliesToType);

        suppliesToType[0] = 2;
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.mintNewContent(contentOwner, suppliesToType);

        suppliesToType[0] = 7;
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.mintNewContent(contentOwner, suppliesToType);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Supply related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_supply_ok() public withEmptySupply(contentId.commonFraktionId()) asDeployer {
        FraktionId commonFraktion = contentId.commonFraktionId();
        // Ensure we start with a supply at 0
        assertEq(fraktionTokens.supplyOf(commonFraktion), 0);

        // Increase it to one
        fraktionTokens.addSupply(commonFraktion, 1);
        assertEq(fraktionTokens.supplyOf(commonFraktion), 1);

        // Ensure the fraktion is mintable and the supplies goes back to 0
        fraktionTokens.mint(user, commonFraktion, 1);
        assertEq(fraktionTokens.supplyOf(commonFraktion), 0);
    }

    function test_supply_InvalidRole_ko() public withEmptySupply(contentId.commonFraktionId()) {
        vm.expectRevert(NotAuthorized.selector);
        fraktionTokens.addSupply(contentId.commonFraktionId(), 1);
    }

    function test_supply_SupplyUpdateNotAllowed_ko() public asDeployer {
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.addSupply(contentId.toFraktionId(0), 1);

        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.addSupply(contentId.toFraktionId(1), 1);

        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.addSupply(contentId.toFraktionId(2), 1);

        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        fraktionTokens.addSupply(contentId.toFraktionId(7), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Burn function                               */
    /* -------------------------------------------------------------------------- */

    function test_burn_ok() public {
        FraktionId commonFraktion = contentId.commonFraktionId();
        uint256 initialSupply = fraktionTokens.supplyOf(commonFraktion);
        vm.prank(deployer);
        fraktionTokens.mint(user, commonFraktion, 1);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktion)), 1);

        // Burn it
        vm.prank(user);
        fraktionTokens.burn(commonFraktion, 1);

        // Assert the balance is back to 0
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktion)), 0);
        // Assert the supply is back to initial state
        assertEq(fraktionTokens.supplyOf(commonFraktion), initialSupply);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Transfer callbacks                             */
    /* -------------------------------------------------------------------------- */

    function test_setUpTransferCallback_ok() public {
        // Setup a bullshit callback
        vm.prank(deployer);
        fraktionTokens.registerNewCallback(address(1));

        // Ensure it's locking the payed fraktion transfer (since callback can't be called)
        vm.expectRevert();
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 1);

        // Ensure it's ok for non supply aware fraktion
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.freeFraktionId(), 1);

        // Update to a more valid callback
        TestFraktionTransferCallback callback = new TestFraktionTransferCallback();
        vm.prank(deployer);
        fraktionTokens.registerNewCallback(address(callback));

        // Ensure it's ok for payed fraktion
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 1);
        assertEq(callback.invocationCount(), 1);

        // Ensure it's ok for non payed fraktion, but it doesn't invoke the callback
        vm.prank(deployer);
        fraktionTokens.mint(user, contentId.freeFraktionId(), 1);
        assertEq(callback.invocationCount(), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test view function                             */
    /* -------------------------------------------------------------------------- */

    function test_batchBalance_ok() public {
        FraktionId commonFraktion = contentId.commonFraktionId();

        // Mint a fraktion to our user
        vm.prank(deployer);
        fraktionTokens.mint(user, commonFraktion, 1);

        // Get the balance directly
        uint256 directBalance = fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktion));

        // Get the balance via a batch fetch
        FraktionId[] memory idsToQuery = new FraktionId[](1);
        idsToQuery[0] = commonFraktion;

        // Get the balances
        uint256[] memory balances = fraktionTokens.balanceOfIdsBatch(user, idsToQuery);
        assertEq(balances[0], directBalance);
    }

    function test_ownerOf_ok() public {
        assertEq(fraktionTokens.ownerOf(contentId), contentOwner);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Permit transfer all                            */
    /* -------------------------------------------------------------------------- */

    function test_permitTransferAll_ok() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitTransferAllSignature(contentOwner, block.timestamp);

        // Perform the permit op & ensure it's valid
        fraktionTokens.permitAllTransfer(user, contentOwner, block.timestamp, v, r, s);

        assertEq(fraktionTokens.isApprovedForAll(user, contentOwner), true);
    }

    function test_permitTransferAll_DelayExpired_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitTransferAllSignature(contentOwner, block.timestamp - 1);

        // Perform the permit op & ensure it's valid
        vm.expectRevert(PermitDelayExpired.selector);
        fraktionTokens.permitAllTransfer(user, contentOwner, block.timestamp - 1, v, r, s);
    }

    function test_permitTransferAll_InvalidSigner_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitTransferAllSignature(contentOwner, block.timestamp);

        // Perform the permit op & ensure it's valid
        vm.expectRevert(InvalidSigner.selector);
        fraktionTokens.permitAllTransfer(address(1), contentOwner, block.timestamp, v, r, s);
    }

    function test_permitTransferAll_InvalidNonce_ko() public {
        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            userPrivKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    fraktionTokens.getDomainSeperator(),
                    keccak256(abi.encode(PERMIT_TRANSFER_ALL_TYPEHASH, user, contentOwner, 1312, block.timestamp))
                )
            )
        );

        // Perform the permit op & ensure it's valid
        vm.expectRevert(InvalidSigner.selector);
        fraktionTokens.permitAllTransfer(user, contentOwner, block.timestamp, v, r, s);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test transfer all                             */
    /* -------------------------------------------------------------------------- */

    function test_transferAllFrom_ok() public {
        // A few fraktion to the users
        vm.startPrank(deployer);
        fraktionTokens.mint(user, contentId.commonFraktionId(), 5);
        fraktionTokens.mint(user, contentId.premiumFraktionId(), 2);
        fraktionTokens.mint(user, contentId.goldFraktionId(), 1);
        vm.stopPrank();

        // Assert the fraktion is minted
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.commonFraktionId())), 5);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.premiumFraktionId())), 2);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.goldFraktionId())), 1);

        // Ask to transfer all of the premium fraktion
        uint256[] memory ids = new uint256[](1);
        ids[0] = FraktionId.unwrap(contentId.premiumFraktionId());

        // Transfer all of the premium fraktion
        address targetUser = _newUser("targetUser");
        vm.prank(user);
        fraktionTokens.transferAllFrom(user, targetUser, ids);

        // Ensure all the premium fraktion are transfered
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.premiumFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.premiumFraktionId())), 2);

        // Build the array with all the fraktion type
        ids = new uint256[](4);
        ids[0] = FraktionId.unwrap(contentId.commonFraktionId());
        ids[1] = FraktionId.unwrap(contentId.premiumFraktionId());
        ids[2] = FraktionId.unwrap(contentId.goldFraktionId());
        ids[3] = FraktionId.unwrap(contentId.diamondFraktionId());

        // Transfer all of them
        vm.prank(user);
        fraktionTokens.transferAllFrom(user, targetUser, ids);

        // Ensure every fraktion type is well transfered
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.commonFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.premiumFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.goldFraktionId())), 0);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(contentId.diamondFraktionId())), 0);

        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.commonFraktionId())), 5);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.premiumFraktionId())), 2);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.goldFraktionId())), 1);
        assertEq(fraktionTokens.balanceOf(targetUser, FraktionId.unwrap(contentId.diamondFraktionId())), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Some helpers                                */
    /* -------------------------------------------------------------------------- */

    function _getMintContentParams() internal pure returns (uint256[] memory suppliesToType) {
        // Build the array of types (payable fraktion type)
        suppliesToType = new uint256[](4);
        suppliesToType[0] = 100 << 4 | ContentIdLib.FRAKTION_TYPE_COMMON;
        suppliesToType[1] = 50 << 4 | ContentIdLib.FRAKTION_TYPE_PREMIUM;
        suppliesToType[2] = 25 << 4 | ContentIdLib.FRAKTION_TYPE_GOLD;
        suppliesToType[3] = 10 << 4 | ContentIdLib.FRAKTION_TYPE_DIAMOND;
    }
}

contract TestFraktionTransferCallback is FraktionTransferCallback {
    uint256 public invocationCount;

    function onFraktionsTransferred(address, address, FraktionId[] memory, uint256[] memory) external payable {
        invocationCount++;
    }
}
