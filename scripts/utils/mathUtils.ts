import { BigNumber, BigNumberish, utils } from "ethers";

export const TOKEN_ID_OFFSET = 4;

export const TOKEN_TYPE_CREATOR = 1;
export const TOKEN_TYPE_FREE = 2;
export const TOKEN_TYPE_COMMON = 3;
export const TOKEN_TYPE_PREMIUM = 4;
export const TOKEN_TYPE_GOLD = 5;
export const TOKEN_TYPE_DIAMOND = 6;

export const BUYABLE_TOKEN_TYPES = [TOKEN_TYPE_COMMON, TOKEN_TYPE_PREMIUM, TOKEN_TYPE_GOLD, TOKEN_TYPE_DIAMOND];

export const allTokenTypesToRarity: { rarity: string; type: number }[] = [
  { rarity: "Creator Nft", type: TOKEN_TYPE_CREATOR },
  { rarity: "Free Fraktion", type: TOKEN_TYPE_FREE },
  { rarity: "Common Fraktion", type: TOKEN_TYPE_COMMON },
  { rarity: "Premium Fraktion", type: TOKEN_TYPE_PREMIUM },
  { rarity: "Gold Fraktion", type: TOKEN_TYPE_GOLD },
  { rarity: "Diamond Fraktion", type: TOKEN_TYPE_DIAMOND },
];

/**
 * Build the id of a nft fraction from a content id and the token type
 * @param {BigNumber} contentId The id of the content for whioch we want to build the fraction id
 * @param {number} tokenType The type of fraction we want
 * @return {BigNumber} The erc1155 token id
 */
export function buildFractionId(contentId: BigNumberish, tokenType: number): BigNumber {
  return BigNumber.from(contentId).shl(TOKEN_ID_OFFSET).or(BigNumber.from(tokenType));
}
