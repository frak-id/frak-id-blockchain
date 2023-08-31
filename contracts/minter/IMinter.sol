// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { IPausable } from "../utils/IPausable.sol";

/**
 * @author  @KONFeature
 * @title   Minter interface
 * @notice  This contract describe the method exposed by the Minter contract
 * @dev     Just an interface to ease the development and upgradeability
 * @custom:security-contact contact@frak.id
 */
interface IMinter is IPausable {
    /**
     * @notice  Mint a new content to the FrkEcosystem
     * @dev     Will ensure the role and contract state, then the param, and finally call the FraktionTokens contract to
     * mint the new content
     * @param   contentOwnerAddress  The address of the owner of the given content
     * @param   commonSupply  The supply desired for each common fraktion of this content
     * @param   premiumSupply  The supply desired for each premium fraktion of this content
     * @param   goldSupply  The supply desired for each gold fraktion of this content
     * @param   diamondSupply  The supply desired for each diamond fraktion of this content
     * @return  contentId  The id of the freshly minted content
     */
    function addContent(
        address contentOwnerAddress,
        uint256 commonSupply,
        uint256 premiumSupply,
        uint256 goldSupply,
        uint256 diamondSupply
    )
        external
        payable
        returns (uint256 contentId);

    /**
     * @notice  Mint a new fraktion for the given amount and user
     * @dev     Will compute the fraktion price, ensure the user have enough Frk to buy it, if try, perform the transfer
     * and mint the fraktion
     * @param   id  The id of the fraktion to be minted for the user
     * @param   to  The address on which we will mint the fraktion
     * @param   deadline  The deadline for the permit of the allowance tx
     * @param   v  Signature spec secp256k1
     * @param   r  Signature spec secp256k1
     * @param   s  Signature spec secp256k1
     */
    function mintFraktionForUser(
        uint256 id,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        payable;

    /**
     * @notice  Mint a new fraktion for the given amount to the caller
     * @dev     Will compute the fraktion price, ensure the user have enough Frk to buy it, if try, perform the transfer
     * and mint the fraktion
     * @param   id  The id of the fraktion to be minted for the user
     * @param   deadline  The deadline for the permit of the allowance tx
     * @param   v  Signature spec secp256k1
     * @param   r  Signature spec secp256k1
     * @param   s  Signature spec secp256k1
     */
    function mintFraktion(uint256 id, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     * @param   to  Address of the user
     */
    function mintFreeFraktionForUser(uint256 id, address to) external payable;

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     */
    function mintFreeFraktion(uint256 id) external payable;

    /**
     * @notice  Increase the total supply for the given fraktion id
     * @dev     Will call our FraktionTokens contract and increase the supply for the given fraktion, only if all of it
     * have been minted
     * @param   id  The id of the fraktion for which we want to increase the supply
     * @param   newSupply  The supply we wan't to append for this fraktion
     */
    function increaseSupply(uint256 id, uint256 newSupply) external;
}
