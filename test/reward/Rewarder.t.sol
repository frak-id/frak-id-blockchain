// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { RewarderTestHelper } from "./RewarderTestHelper.sol";
import { ArrayLib } from "@frak/libs/ArrayLib.sol";
import { ContentId } from "@frak/libs/ContentId.sol";
import { NotAuthorized, InvalidAddress, ContractPaused, BadgeTooLarge } from "@frak/utils/FrakErrors.sol";

/// Testing the rewarder
contract RewarderTest is RewarderTestHelper {
    using ArrayLib for uint256;

    uint256[] fTypeArray = uint256(3).asSingletonArray();

    function setUp() public {
        _baseSetUp();
    }

    /*
     * ===== TEST : initialize(
        address frkTokenAddr,
        address internalTokenAddr,
        address contentPoolAddr,
        address referralAddr,
        address foundationAddr
    ) =====
     */
    function test_fail_InitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize(address(0), address(0), address(0), address(0), address(0));
    }

    /*
     * ===== TEST : updateTpu(uint256 newTpu) =====
     */
    function test_updateTpu() public prankExecAsDeployer {
        rewarder.updateTpu(1 ether);
        assertEq(rewarder.getTpu(), 1 ether);
    }

    function test_fail_updateTpu_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateTpu(1 ether);
    }

    /*
     * ===== TEST : updateContentBadge(
        uint256 contentId,
        uint256 badge
    ) =====
     */
    function test_updateContentBadge() public prankExecAsDeployer {
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);
        rewarder.updateContentBadge(contentId, 2 ether);
        assertEq(rewarder.getContentBadge(contentId), 2 ether);
    }

    function test_fail_updateContentBadge_NotAuthorized() public {
        prankDeployer();
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);

        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_fail_updateContentBadge_BadgeCapReached() public prankExecAsDeployer {
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);

        vm.expectRevert(BadgeTooLarge.selector);
        rewarder.updateContentBadge(contentId, 1001 ether);
    }

    /*
     * ===== TEST : updateListenerBadge(
        address listener,
        uint256 badge
    ) =====
     */
    function test_updateListenerBadge() public prankExecAsDeployer {
        rewarder.updateListenerBadge(address(1), 2 ether);
        assertEq(rewarder.getListenerBadge(address(1)), 2 ether);
    }

    function test_fail_updateListenerBadge_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateListenerBadge(address(1), 2 ether);
    }

    function test_fail_updateListenerBadge_BadgeCapReached() public prankExecAsDeployer {
        vm.expectRevert(BadgeTooLarge.selector);
        rewarder.updateListenerBadge(address(1), 1001 ether);
    }

    /*
     * ===== TEST : multicall(bytes[] calldata data) =====
     */
    function test_multicall_emptyData() public prankExecAsDeployer {
        // Build our calldata
        bytes[] memory callingData = new bytes[](0);
        rewarder.multicall(callingData);
    }

    function test_multicall_singleData() public prankExecAsDeployer {
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);

        // Build our calldata
        bytes[] memory callingData = new bytes[](1);
        callingData[0] = abi.encodeWithSelector(rewarder.updateContentBadge.selector, contentId, 1 ether);

        rewarder.multicall(callingData);
    }

    function test_multicall_multipleData() public prankExecAsDeployer {
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);

        frakToken.mint(address(rewarder), 5 ether);

        // Build our calldata
        bytes[] memory callingData = new bytes[](4);
        callingData[0] = abi.encodeWithSelector(rewarder.updateContentBadge.selector, contentId, 1 ether);
        callingData[1] = abi.encodeWithSelector(rewarder.updateContentBadge.selector, contentId, 2 ether);
        callingData[2] = abi.encodeWithSelector(rewarder.payUserDirectly.selector, address(1), 2 ether);
        callingData[3] = abi.encodeWithSelector(rewarder.payUserDirectly.selector, address(2), 3 ether);

        rewarder.multicall(callingData);

        // Ensure array is executed in the right order
        assertEq(rewarder.getContentBadge(contentId), 2 ether);
        assertEq(frakToken.balanceOf(address(1)), 2 ether);
        assertEq(frakToken.balanceOf(address(2)), 3 ether);
    }

    function test_multicall_reallyLargeData() public prankExecAsDeployer {
        frakToken.mint(address(rewarder), 1000 ether);

        // Build our calldata
        uint256 length = 1000;
        bytes[] memory callingData = new bytes[](length);
        for (uint256 index; index < length; index++) {
            callingData[index] = abi.encodeWithSelector(rewarder.payUserDirectly.selector, address(1), 1 ether);
        }

        rewarder.multicall(callingData);
    }

    function test_fail_multicall_NotAuthorized() public {
        prankDeployer();
        ContentId contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fTypeArray, fTypeArray);

        // Build our calldata
        bytes[] memory callingData = new bytes[](1);
        callingData[0] = abi.encodeWithSelector(rewarder.updateContentBadge.selector, contentId, 1 ether);

        vm.expectRevert(NotAuthorized.selector);
        rewarder.multicall(callingData);
    }
}
