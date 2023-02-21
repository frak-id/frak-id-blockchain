// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

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
}
