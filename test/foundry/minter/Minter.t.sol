// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {NotAuthorized, InvalidAddress, ContractPaused, BadgeTooLarge} from "@frak/utils/FrakErrors.sol";
import {FraktionTokens} from "@frak/tokens/FraktionTokens.sol";
import {FrakToken} from "@frak/tokens/FrakTokenL2.sol";
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
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        prankDeployer();
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(fraktionCommonId), 9);
        assertEq(fraktionTokens.balanceOf(user, fraktionCommonId), 1);
    }

    function test_fail_mintFraktionForUser_ContractPaused() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        prankDeployer();
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        prankDeployer();
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktionForUser_NotAuthorized() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
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
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 1, 0, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildPremiumNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.expectRevert(FraktionTokens.InsuficiantSupply.selector);
        prankDeployer();
        minter.mintFraktionForUser(fraktionCommonId, user, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktionForUser_InvalidFraktionType() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 1, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.expectRevert(InvalidFraktionType.selector);
        prankDeployer();
        minter.mintFraktionForUser(contentId.buildFreeNftId(), user, block.timestamp, v, r, s);
    }

    function test_fail_mintFractionForUser_InvalidSigner() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost - 1);

        // Launch the buy prcess
        prankDeployer();
        vm.expectRevert(FrakToken.InvalidSigner.selector);
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
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
        // Ensure the supply is good
        assertEq(fraktionTokens.supplyOf(fraktionCommonId), 9);
        assertEq(fraktionTokens.balanceOf(user, fraktionCommonId), 1);
    }

    function test_fail_mintFraktion_ContractPaused() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the buy prcess
        prankDeployer();
        minter.pause();
        vm.expectRevert(ContractPaused.selector);
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
    }

    function test_fail_mintFraktion_TooManyFraktion() public {
        uint256 privateKey = 0xACAB;
        address user = vm.addr(privateKey);
        // Add an initial content
        prankDeployer();
        uint256 contentId = minter.addContent(address(1), 10, 1, 1, 1);
        // Mint some token to our user
        prankDeployer();
        frakToken.mint(user, 500 ether);

        // Get the cost of the buy process
        uint256 fraktionCommonId = contentId.buildCommonNftId();
        uint256 cost = minter.getCostBadge(fraktionCommonId);

        // Sign the tx for the user
        (uint8 v, bytes32 r, bytes32 s) = _getSignedPermit(privateKey, cost);

        // Launch the first buy process
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);

        // Sign the tx for the user
        (v, r, s) = _getSignedPermit(privateKey, cost);

        // Launch the second buy process
        vm.expectRevert(FraktionTokens.TooManyFraktion.selector);
        vm.prank(user);
        minter.mintFraktion(fraktionCommonId, block.timestamp, v, r, s);
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
        vm.expectRevert(FraktionTokens.TooManyFraktion.selector);
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
        vm.expectRevert(FraktionTokens.RemainingSupply.selector);
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
