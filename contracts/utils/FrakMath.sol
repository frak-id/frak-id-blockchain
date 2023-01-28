// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

library FrakMath {
    // The offset of the id and the mask we use to store the token type
    uint8 internal constant ID_OFFSET = 4;
    uint8 internal constant TYPE_MASK = 0xF;

    // The mask for the different content specfic types
    uint8 internal constant TOKEN_TYPE_NFT_MASK = 1;
    uint8 internal constant TOKEN_TYPE_FREE_MASK = 2;
    uint8 internal constant TOKEN_TYPE_COMMON_MASK = 3;
    uint8 internal constant TOKEN_TYPE_PREMIUM_MASK = 4;
    uint8 internal constant TOKEN_TYPE_GOLD_MASK = 5;
    uint8 internal constant TOKEN_TYPE_DIAMOND_MASK = 6;

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
    function buildSnftIds(uint256 id, uint256[] memory types) internal pure returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](types.length);
        for (uint256 i; i < types.length;) {
            unchecked {
                tokenIds[i] = buildSnftId(id, types[i]);
                ++i;
            }
        }
        return tokenIds;
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
     * @return uint256 The id without the type mask
     */
    function extractContentId(uint256 id) internal pure returns (uint256) {
        return id >> ID_OFFSET;
    }

    /**
     * @dev Return the token type
     * @param id uint256 ID of the token to extract the mask from
     * @return uint256 The token type
     */
    function extractTokenType(uint256 id) internal pure returns (uint8) {
        return uint8(id & TYPE_MASK);
    }

    /**
     * @dev Return the token type
     * @param id uint256 ID of the token to extract the mask from
     * @return uint256 The token type
     */
    function extractContentIdAndTokenType(uint256 id) internal pure returns (uint256, uint8) {
        return (id >> ID_OFFSET, uint8(id & TYPE_MASK));
    }

    /**
     * @dev Check if the given token exist
     * @param id uint256 ID of the token to check
     * @return bool true if the token is related to a content, false otherwise
     */
    function isContentRelatedToken(uint256 id) internal pure returns (bool) {
        uint8 tokenType = extractTokenType(id);
        return tokenType > TOKEN_TYPE_NFT_MASK && tokenType <= TOKEN_TYPE_DIAMOND_MASK;
    }

    /**
     * @dev Check if the token is payed or not
     */
    function isPayedTokenToken(uint256 tokenType) internal pure returns (bool) {
        return tokenType > TOKEN_TYPE_FREE_MASK && tokenType <= TOKEN_TYPE_DIAMOND_MASK;
    }

    /**
     * @dev Check if the given token id is a content NFT
     * @param id uint256 ID of the token to check
     * @return bool true if the token is a content nft, false otherwise
     */
    function isContentNft(uint256 id) internal pure returns (bool) {
        return extractTokenType(id) == TOKEN_TYPE_NFT_MASK;
    }

    /**
     * @dev Create a singleton array of the given element
     */
    function asSingletonArray(uint256 element) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    /**
     * @dev Create a singleton array of the given element
     */
    function asSingletonArray(address element) internal pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = element;

        return array;
    }
}
