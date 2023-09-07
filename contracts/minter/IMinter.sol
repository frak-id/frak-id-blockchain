// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { ContentId } from "../libs/ContentId.sol";
import { FraktionId } from "../libs/FraktionId.sol";

/// @author @KONFeature
/// @title IMinter
/// @notice Interface for the Minter contract
/// @custom:security-contact contact@frak.id
interface IMinter {
    /* -------------------------------------------------------------------------- */
    /*                                   Error's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Error emitted when the input supply is invalid
    error InvalidSupply();

    /// @dev Error emitted when we only want to mint a free fraktion, and that's not a free fraktion
    error ExpectingOnlyFreeFraktion();

    /// @dev Error emitted when the have more than one fraktions of the given type
    error TooManyFraktion();

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a new content is minted
    event ContentMinted(uint256 baseId, address indexed owner);

    /// @dev Event emitted when a new fraktion for a content is minted
    event FractionMinted(uint256 indexed fraktionId, address indexed user, uint256 amount, uint256 cost);

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
        returns (ContentId contentId);

    /// @dev Add a new auto minted content in our system
    function addAutoMintedContent(address autoMintHolder) external payable returns (ContentId contentId);

    /// @dev Add a content when a creator asked for it
    function addContentForCreator(address contentOwnerAddress) external payable returns (ContentId contentId);

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
        FraktionId id,
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
    function mintFraktion(FraktionId id, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     * @param   to  Address of the user
     */
    function mintFreeFraktionForUser(FraktionId id, address to) external;

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     */
    function mintFreeFraktion(FraktionId id) external;

    /**
     * @notice  Increase the total supply for the given fraktion id
     * @dev     Will call our FraktionTokens contract and increase the supply for the given fraktion, only if all of it
     * have been minted
     * @param   id  The id of the fraktion for which we want to increase the supply
     * @param   newSupply  The supply we wan't to append for this fraktion
     */
    function increaseSupply(FraktionId id, uint256 newSupply) external;
}
