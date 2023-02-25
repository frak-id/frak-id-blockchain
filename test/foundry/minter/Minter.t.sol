// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {NotAuthorized, InvalidAddress, ContractPaused, BadgeTooLarge} from "@frak/utils/FrakErrors.sol";
import {FraktionTokens} from "@frak/tokens/FraktionTokens.sol";
import {FrakMath} from "@frak/utils/FrakMath.sol";
import {FrakRoles} from "@frak/utils/FrakRoles.sol";
import {Minter} from "@frak/minter/Minter.sol";
import {FrkTokenTestHelper} from "../FrkTokenTestHelper.sol";
import {
    NotAuthorized,
    InvalidAddress,
    ContractPaused,
    BadgeTooLarge,
    InvalidFraktionType
} from "@frak/utils/FrakErrors.sol";

/// Testing minter contract
contract MinterTest is FrkTokenTestHelper {
    using FrakMath for address;
    using FrakMath for uint256;

    FraktionTokens fraktionTokens;
    address foundationAddr = address(13);

    address minterAddr;
    Minter minter;

    function setUp() public {
        _setupFrkToken();

        // Deploy fraktions token
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("test_url"));
        address fraktionProxyAddr = deployContract(address(new FraktionTokens()), initData);
        fraktionTokens = FraktionTokens(fraktionProxyAddr);

        // Deploy our minter contract
        initData = abi.encodeCall(Minter.initialize, (address(frakToken), fraktionProxyAddr, foundationAddr));
        minterAddr = deployContract(address(new Minter()), initData);
        minter = Minter(minterAddr);

        // Grant the minter role to our minter contract
        prankDeployer();
        fraktionTokens.grantRole(FrakRoles.MINTER, minterAddr);
    }

    /*
     * ===== TEST : initialize(
        address frkTokenAddr,
        address fraktionTokensAddr,
        address foundationAddr
    ) =====
     */
    function test_fail_InitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        minter.initialize(address(0), address(0), address(0));
    }

    /*
     * ===== TEST : addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 premiumSupply,
        uint256 goldSupply,
        uint256 diamondSupply
    ) =====
     */
    function test_addContent() public prankExecAsDeployer {
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_ContractPaused() public prankExecAsDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_InvalidAddress() public prankExecAsDeployer {
        vm.expectRevert(InvalidAddress.selector);
        minter.addContent(address(0), 1, 1, 1, 1);
    }

    function test_fail_addContent_InvalidSupply() public prankExecAsDeployer {
        vm.expectRevert(Minter.InvalidSupply.selector);
        minter.addContent(address(1), 0, 1, 1, 1);

        vm.expectRevert(Minter.InvalidSupply.selector);
        minter.addContent(address(1), 501, 1, 1, 1);

        vm.expectRevert(Minter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 201, 1, 1);

        vm.expectRevert(Minter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 1, 51, 1);

        vm.expectRevert(Minter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 1, 1, 21);
    }

    /*
     * ===== TEST : mintFractionForUser(
        uint256 id,
        address to,
        uint256 amount
    ) =====
     */
    function test_mintFractionForUser() public {
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(contentId.buildCommonNftId()), 10);
        assertEq(fraktionTokens.supplyOf(contentId.buildDiamondNftId()), 1);
        // Approve the minter for token transfe
        prankDeployer();
        frakToken.mint(address(1), 500 ether);
        vm.prank(address(1));
        frakToken.approve(address(minter), 500 ether);
        // Launch the buy prcess
        prankDeployer();
        minter.mintFractionForUser(contentId.buildCommonNftId(), address(1), 1);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(contentId.buildCommonNftId()), 9);
    }

    function test_fail_mintFractionForUser_ContractPaused() public prankExecAsDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.mintFractionForUser(1, address(1), 1);
    }

    function test_fail_mintFractionForUser_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.mintFractionForUser(1, address(1), 1);
    }

    function test_fail_mintFractionForUser_InsuficiantSupply() public {
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        // Approve the minter for token transfe
        prankDeployer();
        frakToken.mint(address(1), 500 ether);
        vm.prank(address(1));
        frakToken.approve(address(minter), 500 ether);
        // Launch the buy prcess
        prankDeployer();
        vm.expectRevert(FraktionTokens.InsuficiantSupply.selector);
        minter.mintFractionForUser(contentId.buildCommonNftId(), address(1), 2);
    }

    function test_fail_mintFractionForUser_InvalidFraktionType() public {
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        // Approve the minter for token transfe
        prankDeployer();
        frakToken.mint(address(1), 500 ether);
        vm.prank(address(1));
        frakToken.approve(address(minter), 500 ether);
        // Launch the buy prcess
        prankDeployer();
        vm.expectRevert(InvalidFraktionType.selector);
        minter.mintFractionForUser(contentId.buildFreeNftId(), address(1), 2);
    }

    /*
     * ===== TEST : mintFreeFraktionForUser(
        uint256 id,
        address to
    ) =====
     */
    function test_mintFreeFraktionForUser() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        minter.mintFreeFraktionForUser(contentId.buildFreeNftId(), address(1));
    }

    function test_fail_mintFreeFraktionForUser_ContractPaused() public prankExecAsDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.mintFreeFraktionForUser(1, address(1));
    }

    function test_fail_mintFreeFraktionForUser_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.mintFreeFraktionForUser(1, address(1));
    }

    function test_fail_mintFreeFraktionForUser_ExpectingOnlyFreeFraktion() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        vm.expectRevert(Minter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktionForUser(contentId.buildCommonNftId(), address(1));
    }

    function test_fail_mintFreeFraktionForUser_AlreadyHaveFreeFraktion() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        minter.mintFreeFraktionForUser(contentId.buildFreeNftId(), address(1));
        vm.expectRevert(Minter.AlreadyHaveFreeFraktion.selector);
        minter.mintFreeFraktionForUser(contentId.buildFreeNftId(), address(1));
    }

    /*
     * ===== TEST : increaseSupply(uint256 id, uint256 newSupply) =====
     */
    function test_increaseSupply() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Increase it's diamond supply
        minter.increaseSupply(contentId.buildDiamondNftId(), 1);
    }

    function test_fail_increaseSupply_ContractPaused() public prankExecAsDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.increaseSupply(1, 1);
    }

    function test_fail_increaseSupply_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.increaseSupply(1, 1);
    }

    function test_fail_increaseSupply_SupplyUpdateNotAllowed() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Revert cause of free fraktion
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        minter.increaseSupply(contentId.buildFreeNftId(), 1);
        // Revert cause of nft id
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        minter.increaseSupply(contentId.buildNftId(), 1);
    }

    function test_fail_increaseSupply_RemainingSupply() public prankExecAsDeployer {
        // Add an initial content
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Revert cause of free fraktion
        vm.expectRevert(Minter.RemainingSupply.selector);
        minter.increaseSupply(contentId.buildCommonNftId(), 1);
    }

    /*
     * ===== TEST : multicall(bytes[] calldata data) =====
     */
    function test_multicall() public prankExecAsDeployer {
        // Build our calldata
        bytes[] memory callingData = new bytes[](5);
        callingData[0] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[1] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[2] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[3] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[4] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);

        minter.multicall(callingData);
    }

    function test_fail_multicall_NotAuthorized() public {
        // Build our calldata
        bytes[] memory callingData = new bytes[](5);
        callingData[0] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[1] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[2] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[3] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);
        callingData[4] = abi.encodeWithSelector(minter.addContent.selector, address(1), 1, 1, 1, 0);

        vm.expectRevert(NotAuthorized.selector);
        minter.multicall(callingData);
    }
}
