// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { rewarderRole } from "../../scripts/utils/roles";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { expect } from "chai";
import { address0 } from "../utils/test-utils";
import { BigNumber } from "ethers";
import { ReferralPool } from "../../types/contracts/reward/pool/ReferralPool";
import { ContentPool } from "../../types/contracts/reward/pool/ContentPool";
import { cp } from "fs";
import { allTokenTypesToRarity, buildFractionId, BUYABLE_TOKEN_TYPES } from "../../scripts/utils/mathUtils";

// Build our initial reward
const baseReward = BigNumber.from(10).pow(16); // So 0.001 frk

const contentId = BigNumber.from(1);

describe.only("ContentPool", () => {
  let sybelToken: SybelToken;
  let contentPool: ContentPool;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    contentPool = await deployContract("ContentPool", [sybelToken.address]);

    // Grant the rewarder role to the referral contract
    await contentPool.grantRole(rewarderRole, owner.address);

    // Mint some token to the pool
    await sybelToken.mint(contentPool.address, BigNumber.from(10).pow(24));
  });

  describe("Update pool state and add reward", () => {
    it("Initial test", async () => {
      await buildLotOfStates();

      for (let addrIndex = 0; addrIndex < addrs.length; addrIndex++) {
        const addr = addrs[addrIndex];

        // Ask to withdraw the content
        await contentPool["withdrawFounds(address)"](addr.address);
      }
    });
  });

  /**
   * Build a large referee chain with all the known address
   */
  const buildLotOfStates = async () => {
    // Ensure when no referrer are in the chain, no reward are given
    for (let index = 0; index < 5; index++) {
      for (let addrIndex = 0; addrIndex < addrs.length; addrIndex++) {
        for (let typeIndex = 0; typeIndex < BUYABLE_TOKEN_TYPES.length; typeIndex++) {
          const tokenType = BUYABLE_TOKEN_TYPES[typeIndex];
          const addr = addrs[addrIndex];

          // Update the share, and add some reward for this content
          await contentPool.onFraktionsTransfered(address0, addr.address, [buildFractionId(index, tokenType)], [5]);
          await contentPool.addReward(index, BigNumber.from(10).pow(18).mul(10));
        }
      }
    }
  };
});

/*

Base : 
|  ContentPool   ·  addReward              ·           -  ·           -  ·       42 186  ·          680  ·       0.00  │
|  ContentPool   ·  onFraktionsTransfered  ·      90 522  ·     313 795  ·      145 609  ·          680  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     102 351  ·     325 636  ·      213 207  ·           17  ·       0.02  │

Base with a few more unchecked computation : 
|  ContentPool   ·  addReward              ·          -  ·           -  ·        42 107  ·          340  ·       0.00  │
|  ContentPool   ·  onFraktionsTransfered  ·      90 229  ·     306 270  ·      141 027  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     102 062  ·     318 115  ·      209 631  ·           17  ·       0.02  │

Copy the reward state to memory before founds withdraw : 
|  ContentPool   ·  onFraktionsTransfered  ·      90 061  ·     300 150  ·      139678  ·          340  ·       0.02  │
|  Rewarder      ·  withdrawFounds         ·     102 217  ·     312 321  ·      206812  ·           17  ·       0.03  │

Same opti as before but with 5 content pool per user, instead of the 5 same pools updated for each tokens : 
|  ContentPool   ·  onFraktionsTransfered  ·      90 061  ·      166 707  ·      111723  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     202 928  ·    1 245 600  ·      721491  ·           17  ·       0.06  │

Disabling IR compilation to get more precise error
|  ContentPool   ·  onFraktionsTransfered  ·      90 588  ·      166 546  ·      112091  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     207 130  ·    1 246 930  ·      724258  ·           17  ·       0.08  │

Having a splitted memory and storage participant for the withdraw methods : 
|  ContentPool   ·  onFraktionsTransfered  ·      89 355  ·      166 579  ·      111240  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     202 026  ·    1 126 310  ·      662239  ·           17  ·       0.05  │

Removing useless address require in the withdraw all : 
|  ContentPool   ·  onFraktionsTransfered  ·      89 320  ·      166 544  ·      111205  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     201 886  ·    1 126 170  ·      662099  ·           17  ·       0.06  │

Adding some more unchecked operation : 
|  ContentPool   ·  onFraktionsTransfered  ·      88 795  ·      166 496  ·      110802  ·          340  ·       0.02  │
|  Rewarder      ·  withdrawFounds         ·     199 381  ·    1 065 425  ·      630474  ·           17  ·       0.13  │

Reputting a safe checked operation for safety purpose : 
|  ContentPool   ·  onFraktionsTransfered  ·      89 207  ·      166 544  ·      111120  ·          340  ·       0.02  │
|  Rewarder      ·  withdrawFounds         ·     201 321  ·    1 125 605  ·      661534  ·           17  ·       0.10  │


Same test with bigger reward (to ensure we got overflow revertion if needed) : 
|  ContentPool   ·  onFraktionsTransfered  ·      92 007  ·      166 544  ·      111741  ·          340  ·       0.01  │
|  Rewarder      ·  withdrawFounds         ·     201 321  ·    1 125 605  ·      663181  ·           17  ·       0.06  │

*/
