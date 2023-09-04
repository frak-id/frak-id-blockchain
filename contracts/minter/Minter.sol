// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import { IMinter } from "./IMinter.sol";
import { FraktionCostBadges } from "./badges/FraktionCostBadges.sol";
import { ContentId } from "../libs/ContentId.sol";
import { FraktionId } from "../libs/FraktionId.sol";
import { FrakRoles } from "../roles/FrakRoles.sol";
import { FraktionTokens } from "../fraktions/FraktionTokens.sol";
import { IFrakToken } from "../tokens/IFrakToken.sol";
import { FrakAccessControlUpgradeable } from "../roles/FrakAccessControlUpgradeable.sol";
import { InvalidAddress } from "../utils/FrakErrors.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";

/// @author @KONFeature
/// @title Minter
/// @notice This contract will mint new content on the ecosytem, and mint fraktions for the user
/// @custom:security-contact contact@frak.id
contract Minter is IMinter, FrakAccessControlUpgradeable, FraktionCostBadges, Multicallable {
    /* -------------------------------------------------------------------------- */
    /*                                   Error's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev 'bytes4(keccak256(bytes("InvalidAddress()")))'
    uint256 private constant _INVALID_ADDRESS_SELECTOR = 0xe6c4247b;

    /// @dev 'bytes4(keccak256(bytes("InvalidSupply()")))'
    uint256 private constant _INVALID_SUPPLY_SELECTOR = 0x15ae6727;

    /// @dev 'bytes4(keccak256(bytes("ExpectingOnlyFreeFraktion()")))'
    uint256 private constant _EXPECTING_ONLY_FREE_FRAKTION_SELECTOR = 0x121becbf;

    /// @dev 'bytes4(keccak256("TooManyFraktion()"))'
    uint256 private constant _TOO_MANY_FRAKTION_SELECTOR = 0xaa37c4ae;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev 'keccak256("ContentMinted(uint256,address)")'
    uint256 private constant _CONTENT_MINTED_EVENT_SELECTOR =
        0x15d512bd00e3acbb8a53b8fd503e98977b1af7618af12cbf83e463aefe880c1b;

    /// @dev 'keccak256("FractionMinted(uint256,address,uint256,uint256)")'
    uint256 private constant _FRACTION_MINTED_EVENT_SELECTOR =
        0x05941b053f6567cc6c1b84cbbb93a3af6df33035cb6694a8a5ad96208e610ad6;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Reference to the fraktion tokens contract (ERC1155)
    FraktionTokens private fraktionTokens;

    /// @dev Reference to the Frak token contract (ERC20)
    IFrakToken private frakToken;

    /// @dev Address of our foundation wallet (for fee's payment)
    address private foundationWallet;

    /* -------------------------------------------------------------------------- */
    /*                                  Function                                  */
    /* -------------------------------------------------------------------------- */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initial constructor of our minter contract (like constructor but for upgradeable contract)
     * @dev     Will only run on first init, check the address as param, and then same all the param
     * @param   frkTokenAddr  The address of the FrkToken contract
     * @param   fraktionTokensAddr  The address of the FraktionTokens contract
     * @param   foundationAddr  The foundation wallet address
     */
    function initialize(
        address frkTokenAddr,
        address fraktionTokensAddr,
        address foundationAddr
    )
        external
        initializer
    {
        if (frkTokenAddr == address(0) || fraktionTokensAddr == address(0) || foundationAddr == address(0)) {
            revert InvalidAddress();
        }

        // Only for v1 deployment
        __FrakAccessControlUpgradeable_Minter_init();

        fraktionTokens = FraktionTokens(fraktionTokensAddr);
        frakToken = IFrakToken(frkTokenAddr);

        foundationWallet = foundationAddr;

        // Grant the badge updater role to the sender
        _grantRole(FrakRoles.BADGE_UPDATER, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

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
        override
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
        returns (ContentId contentId)
    {
        assembly {
            // Check owner address
            if iszero(contentOwnerAddress) {
                mstore(0x00, _INVALID_ADDRESS_SELECTOR)
                revert(0x1c, 0x04)
            }
            // Check supplies
            if or(
                or(iszero(commonSupply), gt(commonSupply, 500)),
                or(or(gt(premiumSupply, 200), gt(goldSupply, 50)), gt(diamondSupply, 20))
            ) {
                mstore(0x00, _INVALID_SUPPLY_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        // Then set the supply for each fraktion types
        uint256[] memory fraktionTypes;
        uint256[] memory supplies;
        assembly {
            // Init our array's
            fraktionTypes := mload(0x40)
            supplies := add(fraktionTypes, 0x100) // 0x100 Since -> 0 length, then 4 * 32 bytes for each uint256
            // Init our array's length
            mstore(fraktionTypes, 4)
            mstore(supplies, 4)
            // Update our free mem pointer
            mstore(0x40, add(supplies, 0x100))
            // Store the fraktionTypes
            mstore(add(fraktionTypes, 0x20), 3)
            mstore(add(fraktionTypes, 0x40), 4)
            mstore(add(fraktionTypes, 0x60), 5)
            mstore(add(fraktionTypes, 0x80), 6)
            // Store the supplies
            mstore(add(supplies, 0x20), commonSupply)
            mstore(add(supplies, 0x40), premiumSupply)
            mstore(add(supplies, 0x60), goldSupply)
            mstore(add(supplies, 0x80), diamondSupply)
        }
        // Try to mint the new content
        contentId = fraktionTokens.mintNewContent(contentOwnerAddress, fraktionTypes, supplies);
        assembly {
            // Emit the content minted event
            mstore(0, contentId)
            log2(0, 0x20, _CONTENT_MINTED_EVENT_SELECTOR, contentOwnerAddress)
        }
    }

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
        payable
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
        _mintFraktionForUser(id, to, deadline, v, r, s);
    }

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
    function mintFraktion(
        FraktionId id,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        payable
        whenNotPaused
    {
        _mintFraktionForUser(id, msg.sender, deadline, v, r, s);
    }

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     * @param   to  Address of the user
     */
    function mintFreeFraktionForUser(
        FraktionId id,
        address to
    )
        external
        payable
        override
        onlyRole(FrakRoles.MINTER)
        whenNotPaused
    {
        _mintFreeFraktionForUser(id, to);
    }

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     */
    function mintFreeFraktion(FraktionId id) external payable override whenNotPaused {
        _mintFreeFraktionForUser(id, msg.sender);
    }

    /**
     * @notice  Increase the total supply for the given fraktion id
     * @dev     Will call our FraktionTokens contract and increase the supply for the given fraktion, only if all of it
     * have been minted
     * @param   id  The id of the fraktion for which we want to increase the supply
     * @param   newSupply  The supply we wan't to append for this fraktion
     */
    function increaseSupply(FraktionId id, uint256 newSupply) external onlyRole(FrakRoles.MINTER) whenNotPaused {
        // Update the supply
        fraktionTokens.setSupply(FraktionId.unwrap(id), newSupply);
    }

    /**
     * @notice  Update the cost badge for the given fraktion
     * @dev     Call to the FraktionCostBadges subclass to update the cost badge, need the right role and contract
     * unpaused
     * @param   fraktionId The id of the fraktion we will update the badge
     * @param   badge The new badge for the fraktion
     */
    function updateCostBadge(
        FraktionId fraktionId,
        uint96 badge
    )
        external
        override
        onlyRole(FrakRoles.BADGE_UPDATER)
        whenNotPaused
    {
        _updateCostBadge(fraktionId, badge);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Internal write function's                         */
    /* -------------------------------------------------------------------------- */

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
    function _mintFraktionForUser(FraktionId id, address to, uint256 deadline, uint8 v, bytes32 r, bytes32 s) private {
        // Get the current user balance, and exit if he already got a fraktion of this type
        uint256 balance = fraktionTokens.balanceOf(to, FraktionId.unwrap(id));
        if (balance != 0) {
            revert TooManyFraktion();
        }
        // Get the cost of the fraktionId
        uint256 cost = getCostBadge(id);
        assembly {
            // Emit the event
            mstore(0, 1)
            mstore(0x20, cost)
            log3(0, 0x40, _FRACTION_MINTED_EVENT_SELECTOR, id, to)
        }
        // Call the permit functions
        frakToken.permit(to, address(this), cost, deadline, v, r, s);
        // Transfer the tokens
        frakToken.transferFrom(to, foundationWallet, cost);
        // Mint his fraktion
        fraktionTokens.mint(to, FraktionId.unwrap(id), 1);
    }

    /**
     * @notice  Mint a free fraktion for the given user
     * @dev     Will mint a new free FraktionToken for the user, by first ensuring the user doesn't have any fraktion,
     * only performed when contract not paused and by the right person
     * @param   id  Id of the free fraktion
     */
    function _mintFreeFraktionForUser(FraktionId id, address to) private {
        assembly {
            // Check if it's a free fraktion
            if iszero(eq(and(id, 0xF), 0x2)) {
                mstore(0x00, _EXPECTING_ONLY_FREE_FRAKTION_SELECTOR)
                revert(0x1c, 0x04)
            }
        }

        // Get the current user balance, and exit if he already got a fraktion of this type
        uint256 balance = fraktionTokens.balanceOf(to, FraktionId.unwrap(id));
        if (balance != 0) {
            revert TooManyFraktion();
        }

        // If we are all good, mint the free fraktion to the user
        fraktionTokens.mint(to, FraktionId.unwrap(id), 1);
    }
}
