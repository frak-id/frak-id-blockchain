// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../utils/IPausable.sol";

/**
 * @dev Represent our rewarder contract
 */
interface IRewarder is IPausable {
    /**
     * @dev Pay a user for all the listening he have done on different podcast
     */
    function payUser(
        address _listener,
        uint256[] calldata _podcastIds,
        uint16[] calldata _listenCounts
    ) external;
}
