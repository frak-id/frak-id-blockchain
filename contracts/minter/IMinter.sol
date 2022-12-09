// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "../utils/IPausable.sol";

/**
 * @dev Represent our minter contract
 */
interface IMinter is IPausable {
    /**
     * @dev Add a new content to our eco system
     */
    function addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 rareSupply,
        uint256 epicSupply,
        uint256 legendarySupply
    ) external returns (uint256);

    /**
     * @dev Mint a new fraction of nft
     */
    function mintFractionForUser(uint256 id, address to, uint256 amount) external;

    /**
     * @dev Increase the supply for a content
     */
    function increaseSupply(uint256 _id, uint256 _newSupply) external;
}
