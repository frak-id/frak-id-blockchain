// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {RewarderTestHelper} from "./RewarderTestHelper.sol";
import {NotAuthorized, InvalidAddress, ContractPaused, BadgeTooLarge} from "@frak/utils/FrakErrors.sol";

/// Testing the rewarder
contract RewarderTest is RewarderTestHelper {
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
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.updateContentBadge(contentId, 2 ether);
        assertEq(rewarder.getContentBadge(contentId), 2 ether);
    }

    function test_fail_updateContentBadge_ContractPaused() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.pause();

        vm.expectRevert(ContractPaused.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_fail_updateContentBadge_NotAuthorized() public {
        prankDeployer();
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);

        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateContentBadge(contentId, 2 ether);
    }

    function test_fail_updateContentBadge_BadgeCapReached() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(contentOwnerAddress);

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

    function test_fail_updateListenerBadge_ContractPaused() public prankExecAsDeployer {
        rewarder.pause();
        vm.expectRevert(ContractPaused.selector);
        rewarder.updateListenerBadge(address(1), 2 ether);
    }

    function test_fail_updateListenerBadge_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.updateListenerBadge(address(1), 2 ether);
    }

    function test_fail_updateListenerBadge_BadgeCapReached() public prankExecAsDeployer {
        vm.expectRevert(BadgeTooLarge.selector);
        rewarder.updateListenerBadge(address(1), 1001 ether);
    }

    event Test(bytes4 errorCode);
    event TestBis(bytes32 signature);
    event TestId(uint256 id);

    function testSelector() public {
        bytes4 errorSelector = bytes4(keccak256(bytes("InsuficiantSupply()")));
        emit Test(errorSelector);
        errorSelector = bytes4(keccak256(bytes("ContractNotPaused()")));
        emit Test(errorSelector);
        errorSelector = bytes4(keccak256(bytes("RenounceForCallerOnly()")));
        emit Test(errorSelector);
        errorSelector = bytes4(keccak256(bytes("SupplyUpdateNotAllowed()")));
        emit Test(errorSelector);
        errorSelector = bytes4(keccak256(bytes("PoolStateClosed()")));
        emit Test(errorSelector);
        errorSelector = bytes4(keccak256(bytes("PoolStateAlreadyClaimed()")));
        emit Test(errorSelector);

        //  address indexed user, uint256 indexed contentId, uint256 baseUserReward, uint256 earningFactor, uint16 ccuCount
        bytes32 bis = keccak256(bytes("RewardOnContent(address,uint256,uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("RewardWithdrawed(address,uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("ContentOwnerUpdated(uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("SuplyUpdated(uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("SuplyUpdated(uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("ContentMinted(uint256,address)"));
        emit TestBis(bis);
        bis = keccak256(bytes("FractionMinted(uint256,address,uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("PoolRewardAdded(uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("PoolSharesUpdated(uint256,uint256,uint256)"));
        emit TestBis(bis);
        bis = keccak256(bytes("ParticipantSharesUpdated(uint256,uint256,uint256)"));
        emit TestBis(bis);

        uint256 baseId = 4555;
        uint256 solContentId = (baseId << 4) | 5;
        emit TestId(solContentId);
        uint256 assContentId;
        assembly {
            assContentId := 1
        }
        emit TestId(assContentId);
        assembly {
            assContentId := shl(0x5, 1)
        }
        emit TestId(assContentId);
        assembly {
            assContentId := shl(0x5, 2)
        }
        emit TestId(assContentId);
        assembly {
            assContentId := shl(0x5, 3)
        }
        emit TestId(assContentId);
        assembly {
            assContentId := shl(0x5, 4)
        }
        emit TestId(assContentId);
    }
}
