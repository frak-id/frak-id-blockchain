// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {IPausable} from "../utils/IPausable.sol";

/**
 * @dev Represent our rewarder contract
 */
interface IRewarder is IPausable {
    /**
     * @dev Pay a user for all the listening he have done on different badge
     */
    function payUser(address listener, uint8 contentType, uint256[] calldata contentIds, uint16[] calldata listenCounts)
        external payable;
}
