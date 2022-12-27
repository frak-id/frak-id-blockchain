// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { InvalidReward } from "@frak/reward/Rewarder.sol";
import { RewarderTestHelper } from "./RewarderTestHelper.sol";
import { NotAuthorized, InvalidAddress, ContractPaused } from "@frak/utils/FrakErrors.sol";

/// Testing the frak l2 token
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
    function test_payCreatorDirectly() public withFrkToken(rewarderAddr) prankExecAsDeployer {
        fraktionTokens.mintNewContent(contentOwnerAddress);
        rewarder.payUserDirectly(contentOwnerAddress, 10);
    }
}
