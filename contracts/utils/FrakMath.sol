// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

/**
 * @author  @KONFeature
 * @title   FrakMath
 * @notice  Contain some math utils for the Frak ecosystem (token ids, type extractor etc)
 * @custom:security-contact contact@frak.id
 */
library FrakMath {
    /// @dev The offset of the id we use to store the token type
    uint8 internal constant ID_OFFSET = 4;
    /// @dev The mask we use to store the token type in the token id
    uint8 internal constant TYPE_MASK = 0xF;

    /// @dev NFT Token type mask
    uint8 internal constant TOKEN_TYPE_NFT_MASK = 1;
    /// @dev Free Token type mask
    uint8 internal constant TOKEN_TYPE_FREE_MASK = 2;
    /// @dev Common Token type mask
    uint8 internal constant TOKEN_TYPE_COMMON_MASK = 3;
    /// @dev Premium Token type mask
    uint8 internal constant TOKEN_TYPE_PREMIUM_MASK = 4;
    /// @dev Gold Token type mask
    uint8 internal constant TOKEN_TYPE_GOLD_MASK = 5;
    /// @dev Diamond Token type mask
    uint8 internal constant TOKEN_TYPE_DIAMOND_MASK = 6;
    /// @dev If a token type is <= to this value it's not a payed one
    uint8 internal constant PAYED_TOKEN_TYPE_MAX = 7;

    /**
     * @dev Build the id for a S FNT
     */
    function buildSnftId(uint256 id, uint256 tokenType) internal pure returns (uint256 tokenId) {
        unchecked {
            tokenId = (id << ID_OFFSET) | tokenType;
        }
    }

    /**
     * @dev Build the id for a S FNT
     */
    function buildSnftIds(uint256 id, uint256[] memory types) internal pure returns (uint256[] memory tokenIds) {
        uint256 length = types.length;
        tokenIds = new uint256[](length);
        for (uint256 i; i < length;) {
            unchecked {
                tokenIds[i] = buildSnftId(id, types[i]);
                ++i;
            }
        }
    }

    /**
     * @dev Build the id for a NFT
     */
    function buildNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_NFT_MASK;
    }

    /**
     * @dev Build the id for a classic NFT id
     */
    function buildFreeNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_FREE_MASK;
    }

    /**
     * @dev Build the id for a classic NFT id
     */
    function buildCommonNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_COMMON_MASK;
    }

    /**
     * @dev Build the id for a rare NFT id
     */
    function buildPremiumNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_PREMIUM_MASK;
    }

    /**
     * @dev Build the id for a epic NFT id
     */
    function buildGoldNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_GOLD_MASK;
    }

    /**
     * @dev Build the id for a epic NFT id
     */
    function buildDiamondNftId(uint256 id) internal pure returns (uint256) {
        return (id << ID_OFFSET) | TOKEN_TYPE_DIAMOND_MASK;
    }

    /**
     * @dev Build a list of all the payable token types
     */
    function payableTokenTypes() internal pure returns (uint256[] memory) {
        uint256[] memory types = new uint256[](4);
        types[0] = FrakMath.TOKEN_TYPE_COMMON_MASK;
        types[1] = FrakMath.TOKEN_TYPE_PREMIUM_MASK;
        types[2] = FrakMath.TOKEN_TYPE_GOLD_MASK;
        types[3] = FrakMath.TOKEN_TYPE_DIAMOND_MASK;
        return types;
    }

    /**
     * @dev Return the id of a content without the token type mask
     * @param id uint256 ID of the token tto exclude the mask of
     * @return contentId uint256 The id without the type mask
     */
    function extractContentId(uint256 id) internal pure returns (uint256 contentId) {
        assembly {
            contentId := shr(ID_OFFSET, id)
        }
    }

    /**
     * @dev Return the token type
     * @param id uint256 ID of the token to extract the mask from
     * @return tokenType uint256 The token type
     */
    function extractTokenType(uint256 id) internal pure returns (uint256 tokenType) {
        assembly {
            tokenType := and(id, TYPE_MASK)
        }
    }

    /**
     * @dev Return the token type
     * @param id uint256 ID of the token to extract the mask from
     * @return contentId uint256 The content id
     * @return tokenType uint256 The token type
     */
    function extractContentIdAndTokenType(uint256 id) internal pure returns (uint256 contentId, uint256 tokenType) {
        assembly {
            contentId := shr(ID_OFFSET, id)
            tokenType := and(id, TYPE_MASK)
        }
    }

    /**
     * @dev Check if the given token exist
     * @param id uint256 ID of the token to check
     * @return bool true if the token is related to a content, false otherwise
     */
    function isContentRelatedToken(uint256 id) internal pure returns (bool) {
        uint256 tokenType = extractTokenType(id);
        return tokenType > TOKEN_TYPE_NFT_MASK && tokenType <= TOKEN_TYPE_DIAMOND_MASK;
    }

    /**
     * @dev Check if the token is payed or not
     */
    function isPayedTokenToken(uint256 tokenType) internal pure returns (bool isPayed) {
        assembly {
            isPayed := and(gt(tokenType, TOKEN_TYPE_FREE_MASK), lt(tokenType, PAYED_TOKEN_TYPE_MAX))
        }
    }

    /**
     * @dev Check if the given token id is a content NFT
     * @param id uint256 ID of the token to check
     * @return isContent bool true if the token is a content nft, false otherwise
     */
    function isContentNft(uint256 id) internal pure returns (bool isContent) {
        assembly {
            isContent := eq(and(id, TYPE_MASK), TOKEN_TYPE_NFT_MASK)
        }
    }

    /**
     * @dev Create a singleton array of the given element
     */
    function asSingletonArray(uint256 element) internal pure returns (uint256[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            let memPointer := mload(0x40)
            mstore(0x40, add(memPointer, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(memPointer, 0x01)
            mstore(add(memPointer, 0x20), element)

            // Set our array to our mem pointer
            array := memPointer
        }
        return array;
    }

    /**
     * @dev Create a singleton array of the given element
     */
    function asSingletonArray(address element) internal pure returns (address[] memory array) {
        assembly {
            // Get free memory space for our array, and update the free mem space index
            let memPointer := mload(0x40)
            mstore(0x40, add(memPointer, 0x40))

            // Store our array (1st = length, 2nd = element)
            mstore(memPointer, 0x01)
            mstore(add(memPointer, 0x20), element)

            // Set our array to our mem pointer
            array := memPointer
        }
        return array;
    }
}
