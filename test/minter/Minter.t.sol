// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/console.sol";
import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { FraktionTokens } from "contracts/fraktions/FraktionTokens.sol";
import { Minter } from "contracts/minter/Minter.sol";
import { IMinter } from "contracts/minter/IMinter.sol";
import { ContentId, ContentIdLib } from "contracts/libs/ContentId.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";

/// @dev Testing methods on the Minter
contract MinterTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init test's                                */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData =
            abi.encodeCall(Minter.initialize, (address(frakToken), address(fraktionTokens), foundation));
        address proxyAddress = _deployProxy(address(new Minter()), initData, "MinterDeploy");
        minter = Minter(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        minter.initialize(address(frakToken), address(fraktionTokens), foundation);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Add content test's                             */
    /* -------------------------------------------------------------------------- */

    function test_addContent_ok() public {
        // Can add a new content
        vm.prank(deployer);
        ContentId newContentId = minter.addContent(contentOwner, 20, 7, 3, 1);

        // Ensure, the content supply are ok
        assertEq(fraktionTokens.supplyOf(newContentId.commonFraktionId()), 20);
        assertEq(fraktionTokens.supplyOf(newContentId.premiumFraktionId()), 7);
        assertEq(fraktionTokens.supplyOf(newContentId.goldFraktionId()), 3);
        assertEq(fraktionTokens.supplyOf(newContentId.diamondFraktionId()), 1);
    }

    function test_addContent_InvalidRole_ko() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.addContent(contentOwner, 20, 7, 3, 1);
    }

    function test_addContent_InvalidSupply_ko() public asDeployer {
        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(contentOwner, 0, 7, 3, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(contentOwner, 501, 7, 3, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(contentOwner, 20, 201, 3, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(contentOwner, 20, 7, 51, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(contentOwner, 20, 7, 3, 21);
    }

    /// @dev Different mint method's benchmark
    function test_benchmarkAddContent_ok() public asDeployer {
        // Warm up storage
        minter.addAutoMintedContent(contentOwner);
        minter.addContent(contentOwner, 1, 0, 0, 0);

        uint256 gasLeft = gasleft();
        minter.addAutoMintedContent(contentOwner);
        uint256 gasUsed = gasLeft - gasleft();

        console.log("- Automint");
        console.log("-- Automint method used: %d", gasUsed);

        // Build supply for 1 common only
        gasLeft = gasleft();
        minter.addContent(contentOwner, 1, 0, 0, 0);
        gasUsed = gasLeft - gasleft();
        console.log("-- Classic mint method : %d", gasUsed);

        // Creator mint test
        console.log("- Creator");
        gasLeft = gasleft();
        minter.addContentForCreator(contentOwner);
        gasUsed = gasLeft - gasleft();
        console.log("-- Creator method used: %d", gasUsed);

        // Build supply for 20, 7, 3, 1
        gasLeft = gasleft();
        minter.addContent(contentOwner, 20, 7, 3, 1);
        gasUsed = gasLeft - gasleft();
        console.log("-- Classic mint method : %d", gasUsed);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Free fraktion mint                             */
    /* -------------------------------------------------------------------------- */

    function test_mintFreeFraktion_ok() public {
        FraktionId freeFraktionId = contentId.freeFraktionId();

        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId)), 0);
        vm.prank(user);
        minter.mintFreeFraktion(freeFraktionId);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId)), 1);
    }

    function test_mintFreeFraktionForUser_ok() public {
        FraktionId freeFraktionId = contentId.freeFraktionId();

        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId)), 0);
        minter.mintFreeFraktionForUser(freeFraktionId, user);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId)), 1);
    }

    function test_mintFreeFraktion_TooManyFraktion_ko() public {
        // Mint initial fraktion
        FraktionId freeFraktionId = contentId.freeFraktionId();
        vm.prank(user);
        minter.mintFreeFraktion(freeFraktionId);
        uint256 freeFraktionBalance = fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId));

        vm.prank(user);
        minter.mintFreeFraktion(freeFraktionId);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(freeFraktionId)), freeFraktionBalance);
    }

    function test_mintFreeFraktion_ExpectingOnlyFreeFraktion_ko() public {
        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktion(contentId.creatorFraktionId());

        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktion(contentId.commonFraktionId());

        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktion(contentId.goldFraktionId());

        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktion(contentId.premiumFraktionId());

        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktion(contentId.diamondFraktionId());
    }

    /* -------------------------------------------------------------------------- */
    /*                             Payed fraktion mint                            */
    /* -------------------------------------------------------------------------- */

    function test_mintFraktion_ok() public withFrk(user, 100 ether) {
        FraktionId commonFraktionId = contentId.commonFraktionId();
        // Assert the balance is 0
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktionId)), 0);

        // Get the price of the fraktion
        uint256 price = minter.getCostBadge(commonFraktionId);

        // Generate the signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(address(minter), price, block.timestamp);

        // Perform the mint process
        vm.prank(user);
        minter.mintFraktion(commonFraktionId, block.timestamp, v, r, s);

        // Assert the fraktion was minted to the user
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktionId)), 1);
    }

    function test_mintFraktion_TooManyFraktion_ko() public withFrk(user, 100 ether) {
        FraktionId commonFraktionId = contentId.commonFraktionId();

        // Mint first fraktion
        uint256 price = minter.getCostBadge(commonFraktionId);
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(address(minter), price, block.timestamp);
        vm.prank(user);
        minter.mintFraktion(commonFraktionId, block.timestamp, v, r, s);

        // Assert the second mint will fail
        (v, r, s) = _generateUserPermitSignature(address(minter), price, block.timestamp);
        vm.expectRevert(IMinter.TooManyFraktion.selector);
        vm.prank(user);
        minter.mintFraktion(commonFraktionId, block.timestamp, v, r, s);

        // Assert the fraktion was minted to the user
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktionId)), 1);
    }

    function test_mintFraktionForUser_ok() public withFrk(user, 100 ether) {
        FraktionId commonFraktionId = contentId.commonFraktionId();
        // Assert the balance is 0
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktionId)), 0);

        // Get the price of the fraktion
        uint256 price = minter.getCostBadge(commonFraktionId);

        // Generate the signature
        (uint8 v, bytes32 r, bytes32 s) = _generateUserPermitSignature(address(minter), price, block.timestamp);

        // Perform the mint process
        vm.prank(deployer);
        minter.mintFraktionForUser(commonFraktionId, user, block.timestamp, v, r, s);

        // Assert the fraktion was minted to the user
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(commonFraktionId)), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Supply method's                              */
    /* -------------------------------------------------------------------------- */

    function test_increaseSupply_ok() public withEmptySupply(contentId.commonFraktionId()) {
        // Increase the supply of the common fraktion
        FraktionId commonFraktionId = contentId.commonFraktionId();
        vm.prank(deployer);
        minter.increaseSupply(commonFraktionId, 1);

        // Assert the supply was increased
        assertEq(fraktionTokens.supplyOf(commonFraktionId), 1);
    }

    function test_increaseSupply_InvalidRole_ko() public withEmptySupply(contentId.commonFraktionId()) {
        // Increase the supply of the common fraktion
        FraktionId commonFraktionId = contentId.commonFraktionId();
        vm.expectRevert(NotAuthorized.selector);
        minter.increaseSupply(commonFraktionId, 1);
    }
}
