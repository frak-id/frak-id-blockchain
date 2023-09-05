// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FraktionTokens } from "@frak/fraktions/FraktionTokens.sol";
import { FrakToken } from "@frak/tokens/FrakToken.sol";
import { IFrakToken } from "@frak/tokens/IFrakToken.sol";
import { ContentId } from "@frak/libs/ContentId.sol";
import { FraktionId } from "@frak/libs/FraktionId.sol";
import { FrakRoles } from "@frak/roles/FrakRoles.sol";
import { Minter } from "@frak/minter/Minter.sol";
import { IMinter } from "@frak/minter/IMinter.sol";
import { FrakTest } from "../FrakTest.sol";
import {
    NotAuthorized,
    InvalidAddress,
    ContractPaused,
    BadgeTooLarge,
    InvalidFraktionType
} from "@frak/utils/FrakErrors.sol";

/// Testing minter contract
contract MinterTest is FrakTest {
    function setUp() public {
        _setupTests();
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
    function test_addContent() public asDeployer {
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_ContractPaused() public asDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.addContent(address(1), 1, 1, 1, 1);
    }

    function test_fail_addContent_InvalidAddress() public asDeployer {
        vm.expectRevert(InvalidAddress.selector);
        minter.addContent(address(0), 1, 1, 1, 1);
    }

    function test_fail_addContent_InvalidSupply() public asDeployer {
        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(address(1), 0, 1, 1, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(address(1), 501, 1, 1, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 201, 1, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 1, 51, 1);

        vm.expectRevert(IMinter.InvalidSupply.selector);
        minter.addContent(address(1), 1, 1, 1, 21);
    }

    /*
     * ===== TEST : mintFraktionForUser(
        uint256 id,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) =====
     */
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev Get permit signature for the given private key and cost
    function _getSignedPermit(uint256 privateKey, uint256 cost) private view returns (uint8 v, bytes32 r, bytes32 s) {
        address user = vm.addr(privateKey);
        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    frakToken.getDomainSeperator(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, user, address(minter), cost, frakToken.getNonce(user), block.timestamp
                        )
                    )
                )
            )
        );
    }

    function test_mintFraktionForUser() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.prank(deployer);
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(fraktionCommonId), 9);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(fraktionCommonId)), 1);
    }

    function test_fail_mintFraktionForUser_ContractPaused() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.prank(deployer);
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        vm.prank(deployer);
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktionForUser_NotAuthorized() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.expectRevert(NotAuthorized.selector);
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktionForUser_InsuficiantSupply() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 1, 0, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.premiumFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.expectRevert(FraktionTokens.InsuficiantSupply.selector);
        vm.prank(deployer);
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktionForUser_InvalidFraktionType() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.expectRevert(InvalidFraktionType.selector);
        vm.prank(deployer);
        minter.mintFraktionForUser(contentId.freeFraktionId(), user, block.timestamp, v, r, s);
    }

    function test_fail_mintFractionForUser_InvalidSigner() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost - 1);

        // Launch the buy prcess
        vm.prank(deployer);
        vm.expectRevert(IFrakToken.InvalidSigner.selector);
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
        // Ensure the supply hasn't changed
        assertEq(fraktionTokens.supplyOf(fraktionCommonId), 10);
    }

    /*
     * ===== TEST : mintFraktion(
        uint256 id,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) =====
     */
    function test_mintFraktion() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(fraktionCommonId), 9);
        assertEq(fraktionTokens.balanceOf(user, FraktionId.unwrap(fraktionCommonId)), 1);
    }

    function test_fail_mintFraktion_ContractPaused() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.prank(deployer);
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktion_TooManyFraktion() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        vm.prank(deployer);
        ContentId contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        vm.prank(deployer);
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        FraktionId fraktionCommonId = contentId.commonFraktionId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the first buy process
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);

        // Sign the tx for the user
        (v, r, s) = _getSignedPermit(privateKey, cost);

        // Launch the second buy process
        vm.expectRevert(IMinter.TooManyFraktion.selector);
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
    }

    /*
     * ===== TEST : mintFreeFraktionForUser(
        uint256 id,
        address to
    ) =====
     */
    function test_mintFreeFraktionForUser() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 1);
        minter.mintFreeFraktionForUser(contentId.freeFraktionId(), address(1));
    }

    function test_fail_mintFreeFraktionForUser_ContractPaused() public asDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.mintFreeFraktionForUser(FraktionId.wrap(1), address(1));
    }

    function test_fail_mintFreeFraktionForUser_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.mintFreeFraktionForUser(FraktionId.wrap(1), address(1));
    }

    function test_fail_mintFreeFraktionForUser_ExpectingOnlyFreeFraktion() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 1);
        vm.expectRevert(IMinter.ExpectingOnlyFreeFraktion.selector);
        minter.mintFreeFraktionForUser(contentId.commonFraktionId(), address(1));
    }

    function test_fail_mintFreeFraktionForUser_AlreadyHaveFreeFraktion() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 1);
        minter.mintFreeFraktionForUser(contentId.freeFraktionId(), address(1));
        vm.expectRevert(IMinter.TooManyFraktion.selector);
        minter.mintFreeFraktionForUser(contentId.freeFraktionId(), address(1));
    }

    /*
     * ===== TEST : increaseSupply(uint256 id, uint256 newSupply) =====
     */
    function test_increaseSupply() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Increase it's diamond supply
        minter.increaseSupply(contentId.diamondFraktionId(), 1);
    }

    function test_fail_increaseSupply_ContractPaused() public asDeployer {
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        minter.increaseSupply(FraktionId.wrap(1), 1);
    }

    function test_fail_increaseSupply_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        minter.increaseSupply(FraktionId.wrap(1), 1);
    }

    function test_fail_increaseSupply_SupplyUpdateNotAllowed() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Revert cause of free fraktion
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        minter.increaseSupply(contentId.freeFraktionId(), 1);
        // Revert cause of nft id
        vm.expectRevert(FraktionTokens.SupplyUpdateNotAllowed.selector);
        minter.increaseSupply(contentId.creatorFraktionId(), 1);
    }

    function test_fail_increaseSupply_RemainingSupply() public asDeployer {
        // Add an initial content
        ContentId contentId = minter.addContent(address(1), 1, 1, 1, 0);
        // Revert cause of free fraktion
        vm.expectRevert(FraktionTokens.RemainingSupply.selector);
        minter.increaseSupply(contentId.commonFraktionId(), 1);
    }

    /*
     * ===== TEST : multicall(bytes[] calldata data) =====
     */
    function test_multicall() public asDeployer {
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
