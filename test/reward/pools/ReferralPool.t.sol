// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { ReferralPool } from "contracts/reward/referralPool/ReferralPool.sol";

/// @dev Testing methods on the ReferralPool
contract ReferralPoolTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init tests                                 */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(ReferralPool.initialize, (address(frakToken)));
        address proxyAddress = _deployProxy(address(new ReferralPool()), initData, "ReferralPoolDeploy");
        referralPool = ReferralPool(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        referralPool.initialize(address(frakToken));
    }
}
