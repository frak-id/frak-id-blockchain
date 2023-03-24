// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {StdUtils} from "@forge-std/StdUtils.sol";
import {Rewarder} from "@frak/reward/Rewarder.sol";
import {FrakMath} from "@frak/utils/FrakMath.sol";
import {ContractPaused, NotAuthorized, InvalidArray, InvalidAddress, RewardTooLarge} from "@frak/utils/FrakErrors.sol";
import {RewarderTestHelper} from "./RewarderTestHelper.sol";

/// Testing the rewarder pay function
contract RewarderPayTest is RewarderTestHelper, StdUtils {
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
        vm.expectRevert(Rewarder.InvalidReward.selector);
        rewarder.payUserDirectly(address(1), 0);
    }

    function test_fail_payUserDirectly_TooLargeReward() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        vm.expectRevert(Rewarder.InvalidReward.selector);
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
        vm.expectRevert(Rewarder.InvalidReward.selector);
        rewarder.payCreatorDirectlyBatch(contentId.asSingletonArray(), uint256(0).asSingletonArray());
    }

    function test_fail_payCreatorDirectlyBatch_TooLargeAmount()
        public
        withLotFrkToken(rewarderAddr)
        prankExecAsDeployer
    {
        vm.expectRevert(Rewarder.InvalidReward.selector);
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
        (uint256[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_payUser_LargeReward() public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        mintFraktions(address(1), 20);

        (uint256[] memory listenCounts, uint256[] memory contentIds) = basePayParam(300);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function testFuzz_payUser(uint16 listenCount) public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        listenCount = uint16(bound(listenCount, 1, 300));

        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = listenCount;

        // Get the previous claimable balance
        uint256 claimableBalance = rewarder.getAvailableFounds(address(1));
        uint256 frakMinted = rewarder.getFrkMinted();
        // Launch the pay
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
        // Ensure the claimable balance has increase
        assertGt(rewarder.getAvailableFounds(address(1)), claimableBalance);
        assertGt(rewarder.getFrkMinted(), frakMinted);
    }

    function testFuzz_payUser_WithFraktions(uint16 listenCount)
        public
        withLotFrkToken(rewarderAddr)
        prankExecAsDeployer
    {
        listenCount = uint16(bound(listenCount, 1, 300));

        mintFraktions(address(1));

        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = listenCount;
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
    }

    function testFuzz_payUser_WithFraktions_ClaimRewards(uint16 listenCount)
        public
        withLotFrkToken(rewarderAddr)
        prankExecAsDeployer
    {
        listenCount = uint16(bound(listenCount, 1, 300));

        mintFraktions(address(1));

        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = listenCount;
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);

        // Self claim rewarder reward
        uint256 balance = frakToken.balanceOf(address(1));
        uint256 availableFound = rewarder.getAvailableFounds(address(1));
        vm.stopPrank();
        vm.prank(address(1));
        rewarder.withdrawFounds();
        // Ensure the balance had increase of the 98% available found
        assertEq(frakToken.balanceOf(address(1)), balance + ((availableFound * 98) / 100));
        balance = frakToken.balanceOf(address(1));

        // Ensure the foundation doesn't have any fee's
        balance = frakToken.balanceOf(foundationAddr);
        availableFound = rewarder.getAvailableFounds(foundationAddr);
        vm.prank(foundationAddr);
        rewarder.withdrawFounds();
        assertEq(frakToken.balanceOf(foundationAddr), balance + availableFound);

        // Compute and claim content pool rewards
        balance = frakToken.balanceOf(address(1));
        vm.prank(address(1));
        contentPool.withdrawFounds();
        assertGt(frakToken.balanceOf(address(1)), balance);
    }

    function testFuzz_payUser_WithFraktionsAndLoadOfState(uint16 listenCount)
        public
        withLotFrkToken(rewarderAddr)
        prankExecAsDeployer
    {
        listenCount = uint16(bound(listenCount, 1, 300));

        mintFraktions(address(1));
        mintFraktions(address(2));

        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = listenCount;
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);

        mintFraktions(address(3));
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
        mintFraktions(address(4));
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
        mintFraktions(address(5));
        rewarder.payUser(address(1), 1, contentId.asSingletonArray(), listenCounts);
    }

    function test_fail_payUser_ContractPaused() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        rewarder.pause();

        vm.expectRevert(ContractPaused.selector);
        (uint256[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_NotRewarder() public withFrkToken(rewarderAddr) {
        (uint256[] memory listenCounts, uint256[] memory contentIds) = basePayParam();
        vm.expectRevert(NotAuthorized.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_TooLargeArray() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint256[] memory listenCounts = new uint256[](21);
        uint256[] memory contentIds = new uint256[](21);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_ArrayNotSameSize() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        uint256[] memory listenCounts = new uint256[](4);
        uint256[] memory contentIds = new uint256[](3);
        vm.expectRevert(InvalidArray.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_RewardTooLarge() public withLotFrkToken(rewarderAddr) prankExecAsDeployer {
        // Mint tokens for the user
        mintFraktions(address(1), 100);

        // Then try to pay him
        (uint256[] memory listenCounts, uint256[] memory contentIds) = basePayParam(300);
        vm.expectRevert(RewardTooLarge.selector);
        rewarder.payUser(address(1), 1, contentIds, listenCounts);
    }

    function test_fail_payUser_InexistantContent() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        // Then try to pay him
        (uint256[] memory listenCounts,) = basePayParam();
        vm.expectRevert(InvalidAddress.selector);
        rewarder.payUser(address(1), 1, uint256(13).asSingletonArray(), listenCounts);
    }

    /*
     * ===== UTILS=====
     */

    function basePayParam() private view returns (uint256[] memory, uint256[] memory) {
        return basePayParam(50);
    }

    function basePayParam(uint16 listenCount) private view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = listenCount;
        return (listenCounts, contentId.asSingletonArray());
    }

    function mintFraktions(address target) private {
        mintFraktions(target, 10);
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
