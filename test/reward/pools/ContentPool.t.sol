// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { FrakTest } from "../../FrakTest.sol";
import { NotAuthorized, InvalidAddress, NoReward, RewardTooLarge, InvalidArray } from "contracts/utils/FrakErrors.sol";
import { ContentPool } from "contracts/reward/contentPool/ContentPool.sol";

/// @dev Testing methods on the ContentPool
contract ContentPoolTest is FrakTest {
    function setUp() public {
        _setupTests();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Init test's                                */
    /* -------------------------------------------------------------------------- */

    function test_canBeDeployedAndInit_ok() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(ContentPool.initialize, (address(frakToken)));
        address proxyAddress = _deployProxy(address(new ContentPool()), initData, "ContentPoolDeploy");
        contentPool = ContentPool(proxyAddress);
    }

    /// @dev Can't re-init
    function test_initialize_InitTwice_ko() public {
        vm.expectRevert("Initializable: contract is already initialized");
        contentPool.initialize(address(frakToken));
    }
}
