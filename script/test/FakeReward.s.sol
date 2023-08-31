// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { UpgradeScript } from "../utils/UpgradeScript.s.sol";
import { Rewarder } from "@frak/reward/Rewarder.sol";

contract FakeRewardScript is UpgradeScript {
    function run() external {
        // Get the current treasury wallet address
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Update all the proxy
        _fakeSomeReward(Rewarder(addresses.rewarder), address(0xe4959298c6aB9C811C80F0BF74aabE7Af95062A6));
    }

    /// @dev Fake some reward for a user
    function _fakeSomeReward(Rewarder rewarder, address user) internal deployerBroadcast {
        uint256[] memory contentIds = new uint256[](1);
        contentIds[0] = 3;

        uint256[] memory listenCounts = new uint256[](1);
        listenCounts[0] = 300;

        rewarder.payUser(user, 1, contentIds, listenCounts);
    }
}
