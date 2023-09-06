// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { Rewarder } from "contracts/reward/Rewarder.sol";

/// @dev Testing methods on the Rewarder
contract RewarderTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init test's                                */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(
            Rewarder.initialize,
            (address(frakToken), address(fraktionTokens), address(contentPool), address(referralPool), foundation)
        );
        address proxyAddress = _deployProxy(address(new Rewarder()), initData, "RewarderDeploy");
        rewarder = Rewarder(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize(
            address(frakToken), address(fraktionTokens), address(contentPool), address(referralPool), foundation
        );
    }
}
