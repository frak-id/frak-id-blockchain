// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/console.sol";
import {ContentPool} from "@frak/reward/pool/ContentPool.sol";
import {FrakMath} from "@frak/utils/FrakMath.sol";
import {FrakRoles} from "@frak/utils/FrakRoles.sol";
import {NotAuthorized, InvalidAddress, ContractPaused, NoReward} from "@frak/utils/FrakErrors.sol";
import {FrkTokenTestHelper} from "../../FrkTokenTestHelper.sol";

/// Testing the content pool
contract ContentPoolTest is FrkTokenTestHelper {
    using FrakMath for uint256;

    ContentPool contentPool;

    function setUp() public {
        _setupFrkToken();

        // Deploy content pool
        bytes memory initData = abi.encodeCall(ContentPool.initialize, (address(frakToken)));
        address contentPoolProxyAddr = deployContract(address(new ContentPool()), initData);
        contentPool = ContentPool(contentPoolProxyAddr);

        prankDeployer();
        frakToken.mint(address(contentPool), 1_000 ether);

        prankDeployer();
        contentPool.grantRole(FrakRoles.REWARDER, deployer);
        prankDeployer();
        contentPool.grantRole(FrakRoles.TOKEN_CONTRACT, deployer);
    }

    /*
     * ===== TEST : initialize(address frkTokenAddr) =====
     */
    function test_fail_InitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        contentPool.initialize(address(0));
    }

    /*
     * ===== TEST : addReward(uint256 contentId, uint256 rewardAmount) =====
     */
    function test_addReward() public prankExecAsDeployer {
        contentPool.addReward(1, 1 ether);
    }

    function test_fail_addReward_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        contentPool.addReward(1, 1 ether);
    }

    function test_fail_addReward_ContractPaused() public prankExecAsDeployer {
        contentPool.pause();

        vm.expectRevert(ContractPaused.selector);
        contentPool.addReward(1, 1 ether);
    }

    function test_fail_addReward_NoReward() public prankExecAsDeployer {
        vm.expectRevert(NoReward.selector);
        contentPool.addReward(1, 0);

        vm.expectRevert(NoReward.selector);
        contentPool.addReward(1, 100_001 ether);
    }

    function test_fullProcess() public prankExecAsDeployer {
        // Add some initial reward
        contentPool.addReward(1, 1 ether);

        // Update a user shares
        contentPool.onFraktionsTransferred(
            address(0), address(1), uint256(1).buildPremiumNftId().asSingletonArray(), uint256(1).asSingletonArray()
        );

        // Compute it's reward
        contentPool.computeAllPoolsBalance(address(1));
    }

    // Test the transfer of fraktion betwen two users
    function test_transferFraktion() public prankExecAsDeployer {
        // Add some initial reward
        console.log("");
        console.log("- Add some initial reward");
        contentPool.addReward(1, 2 ether);

        uint256[] memory fraktionIds = new uint256[](2);
        fraktionIds[0] = uint256(1).buildPremiumNftId();
        fraktionIds[1] = uint256(1).buildGoldNftId();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 1;

        // Update a user shares
        console.log("");
        console.log("- Simulate fraktion mint");
        contentPool.onFraktionsTransferred(address(0), address(1), fraktionIds, amounts);

        // Add a few other rewards
        console.log("");
        console.log("- Add new reward");
        contentPool.addReward(1, 10 ether);

        // Compute it's reward
        console.log("");
        console.log("- Compute balance");
        contentPool.computeAllPoolsBalance(address(1));

        // Assert the user has pending founds
        assertEq(contentPool.getAvailableFounds(address(1)), 12 ether);

        contentPool.withdrawFounds(address(1));
        assertEq(contentPool.getAvailableFounds(address(1)), 0);
        assertEq(frakToken.balanceOf(address(1)), 12 ether);

        // Transfer the fraktion to user2
        console.log("");
        console.log("- Transfer to user 2");
        contentPool.onFraktionsTransferred(address(1), address(2), fraktionIds, amounts);
        // Ensure the fraktion transfer didn't trigger any new movment
        assertEq(contentPool.getAvailableFounds(address(1)), 0);
        assertEq(contentPool.getAvailableFounds(address(2)), 0);

        // Add a few other rewards
        contentPool.addReward(1, 20 ether);

        console.log("");
        console.log("- Compute user 2");
        contentPool.computeAllPoolsBalance(address(2));
        // contentPool.getParticipantStates(address(2));
        assertEq(contentPool.getAvailableFounds(address(2)), 20 ether);

        // Mint a few more fraktion to user 3
        contentPool.onFraktionsTransferred(address(0), address(3), fraktionIds, amounts);
        contentPool.addReward(1, 20 ether);

        // Mint a few more fraktion to user 3
        contentPool.onFraktionsTransferred(address(0), address(4), fraktionIds, amounts);
        contentPool.onFraktionsTransferred(address(0), address(5), fraktionIds, amounts);
        contentPool.addReward(1, 20 ether);

        console.log("");
        console.log("- Compute user 2");
        contentPool.computeAllPoolsBalance(address(2));
        assertEq(contentPool.getAvailableFounds(address(2)), 35 ether);

        // Mint a few more fraktion to user 3
        contentPool.onFraktionsTransferred(address(4), address(0), fraktionIds, amounts);
        contentPool.onFraktionsTransferred(address(5), address(0), fraktionIds, amounts);
        contentPool.addReward(1, 20 ether);

        contentPool.computeAllPoolsBalance(address(2));
        assertEq(contentPool.getAvailableFounds(address(2)), 45 ether);

        contentPool.computeAllPoolsBalance(address(4));
        assertEq(contentPool.getAvailableFounds(address(4)), 5 ether);

        contentPool.computeAllPoolsBalance(address(5));
        assertEq(contentPool.getAvailableFounds(address(5)), 5 ether);
    }
}
