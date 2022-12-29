// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { FrakMath } from "@frak/utils/FrakMath.sol";
import { ContractPaused, NotAuthorized, InvalidArray, InvalidAddress, RewardTooLarge } from "@frak/utils/FrakErrors.sol";
import { RewarderTestHelper } from "./RewarderTestHelper.sol";
import { InvalidReward } from "@frak/reward/Rewarder.sol";

/// Testing the frak l2 token
contract RewarderPayTest is RewarderTestHelper {
    using FrakMath for uint256;

    uint256 contentId;

    function setUp() public {
        _baseSetUp();

        contentId = mintAContent();
    }

    /*
     * ===== TEST : payUserDirectly(address listener, uint256 amount) =====
     */
    function test_payUserDirectly() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payUserDirectly(address(1), 10);
    }

    function test_fail_payUserDirectly_ContractPaused() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.pause();
        vm.expectRevert(ContractPaused.selector);
        rewarder.payUserDirectly(address(1), 10);
    }

    function test_fail_payUserDirectly_InvalidRole() public withFrkToken(rewarderAddr) {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payUserDirectly(address(1), 10);
    }

    function test_fail_payUserDirectly_InvalidAddress() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidAddress.selector);
        rewarder.payUserDirectly(address(0), 10);
    }

    function test_fail_payUserDirectly_InvalidReward() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidReward.selector);
        rewarder.payUserDirectly(address(1), 0);
    }

    function test_fail_payUserDirectly_TooLargeReward() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidReward.selector);
        rewarder.payUserDirectly(address(1), 1_000_001 ether);
    }

    function test_fail_payUserDirectly_NotEnoughBalance() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        rewarder.payUserDirectly(address(1), 11);
    }

    /*
     * ===== TEST : payCreatorDirectlyBatch(
        uint256[] calldata contentIds,
        uint256[] calldata amounts
    ) =====
     */
    function test_payCreatorDirectlyBatch() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(10).asSingletonArray());
    }

    function test_fail_payCreatorDirectlyBatch_ContractPaused() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.pause();
        vm.expectRevert(ContractPaused.selector);
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(10).asSingletonArray());
    }

    function test_fail_payCreatorDirectlyBatch_InvalidRole() public withFrkToken(rewarderAddr) {
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(10).asSingletonArray());
    }

    function test_fail_payCreatorDirectlyBatch_InvalidArray() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint256[] memory contentIds = new uint256[](3);
        uint256[] memory amountsIds = new uint256[](4);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_fail_payCreatorDirectlyBatch_TooLargeArray() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint256[] memory contentIds = new uint256[](21);
        uint256[] memory amountsIds = new uint256[](21);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payCreatorDirectlyBatch(contentIds, amountsIds);
    }

    function test_fail_payCreatorDirectlyBatch_EmptyAmount() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert(InvalidReward.selector);
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(0).asSingletonArray());
    }

    function test_fail_payCreatorDirectlyBatch_TooLargeAmount()
        public
        withLotFrkToken(rewarderAddr)
        prankExecAsDeployer
    {
        vm.expectRevert(InvalidReward.selector);
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(1_000_001 ether).asSingletonArray());
    }

    /*
     * ===== TEST : payUser(
        address listener,
        uint8 contentType,
        uint256[] calldata contentIds,
        uint16[] calldata listenCounts
    )s =====
     */
    function test_payUser() public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        (uint16[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_payUser_LargeReward() public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        mintFraktions(address(1), 20);

        (uint16[] memory listenCounts, uint256[] memory contentIds) = basePayParam(300);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function testFuzz_payUser(uint16 listenCount) public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.assume(listenCount < 300);

        if (listenCount % 2 == 0) {
            mintFraktions(address(1), 10);
        }

        uint16[] memory listenCounts = new uint16[](1);
        listenCounts[0] = listenCount;
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
    }

    function test_fail_payUser_ContractPaused() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.pause();

        vm.expectRevert(ContractPaused.selector);
        (uint16[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_NotRewarder() public withFrkToken(rewarderAddr) {
        (uint16[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_TooLargeArray() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint16[] memory listenCounts = new uint16[](21);
        uint256[] memory contentIds = new uint256[](21);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_ArrayNotSameSize() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint16[] memory listenCounts = new uint16[](4);
        uint256[] memory contentIds = new uint256[](3);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_RewardTooLarge() public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        // Mint tokens for the user
        mintFraktions(address(1), 100);

        // Then try to pay him
        (uint16[] memory listenCounts, uint256[] memory contentIds) = basePayParam(300);
        vm.expectRevert(RewardTooLarge.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_InexistantContent() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        // Then try to pay him
        (uint16[] memory listenCounts, ) = basePayParam();
        vm.expectRevert(InvalidAddress.selector);
        rewarder.payUser(address(1), 1, uint256(13).asSingletonArray(), listenCounts);
    }

    /*
     * ===== UTILS=====
     */

    function basePayParam() private view returns (uint16[] memory, uint256[] memory) {
        return basePayParam(50);
    }

    function basePayParam(uint16 listenCount) private view returns (uint16[] memory, uint256[] memory) {
        uint16[] memory listenCounts = new uint16[](1);
        listenCounts[0] = listenCount;
        return (listenCounts, contentId.asSingletonArray());
    }

    function mintFraktions(address target, uint256 amount) private {
        uint256[] memory fraktionIds = contentId.buildSnftIds(FrakMath.payableTokenTypes());
        uint256[] memory amounts = new uint256[](fraktionIds.length);
        for (uint256 i = 0; i < fraktionIds.length; i++) {
            amounts[i] = amount;
        }
        fraktionTokens.setSupplyBatch(fraktionIds, amounts);
        for (uint256 i = 0; i < fraktionIds.length; i++) {
            fraktionTokens.mint(target, fraktionIds[i], amount);
        }
    }
}
