// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { minterRole, rewarderRole } from "../../scripts/utils/roles";
import { ContentOwnerUpdatedEvent, SybelInternalTokens } from "../../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { Rewarder } from "../../types/contracts/reward/Rewarder";
import { buildFractionId, BUYABLE_TOKEN_TYPES, TOKEN_TYPE_GOLD } from "../../scripts/utils/mathUtils";
import { ReferralPool } from "../../types/contracts/reward/pool/ReferralPool";
import { ContentPool } from "../../types/contracts/reward/pool/ContentPool";

describe.only("Rewarder", () => {
  let sybelToken: SybelToken;
  let internalToken: SybelInternalTokens;
  let referral: ReferralPool;
  let contentPool: ContentPool;
  let rewarder: Rewarder;

  const contentIds: BigNumber[] = [];
  const ccus: number[] = [];

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    internalToken = await deployContract("SybelInternalTokens");
    referral = await deployContract("ReferralPool", [sybelToken.address]);
    contentPool = await deployContract("ContentPool", [sybelToken.address]);
    rewarder = await deployContract("Rewarder", [
      sybelToken.address,
      internalToken.address,
      contentPool.address,
      referral.address,
    ]);

    // Grant the minter role on the rewarder contract for our nft and frak
    await internalToken.grantRole(minterRole, rewarder.address);
    await sybelToken.grantRole(minterRole, rewarder.address);

    // Grant the rewarder role to the referral contract
    await referral.grantRole(rewarderRole, rewarder.address);
    await contentPool.grantRole(rewarderRole, rewarder.address);

    // Setup the callback on the internal tokens for our content pool
    await internalToken.registerNewCallback(contentPool.address);

    for (let index = 0; index < 5; index++) {
      // Perform a mint and we will use this one as content id reference
      const mintEventTxReceipt = await internalToken.mintNewContent(addr1.address);

      // Extract the content id from mint tx
      const mintReceipt = await mintEventTxReceipt.wait();
      const ownerUpdateEvent = mintReceipt.events?.filter(contractEvent => {
        return contractEvent.event == "ContentOwnerUpdated";
      })[0] as ContentOwnerUpdatedEvent;
      if (!ownerUpdateEvent || !ownerUpdateEvent.args) throw new Error("Unable to find creation event");
      const mintedTokenId = ownerUpdateEvent.args.id;
      contentIds.push(ownerUpdateEvent.args.id);
      ccus.push(50);

      // Set the supply for each tokens
      for (const tokenType of BUYABLE_TOKEN_TYPES) {
        await internalToken.setSupplyBatch([buildFractionId(mintedTokenId, tokenType)], [100000]);
      }
    }
  });

  describe("Base reward", () => {
    it("Single free reward account", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, [contentIds[0]], [100]);
      // Going throught it a second time to prevent fraktion mint
      await rewarder.payUser(addr1.address, [contentIds[0]], [100]);
    });
    it("Tone of free reward", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, contentIds, ccus);

      // Perform the run a second time so we don't go past the free fraktion mint
      await rewarder.payUser(addr1.address, contentIds, ccus);
    });
    it("Multiple free reward", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, contentIds, ccus);
    });
    it("Reward with payed account", async () => {
      // Mint token for each user
      await mintTokenForEachUser();
      // Rewarder with only one payed fraktion
      await rewarder.payUser(addr1.address, contentIds, ccus);
    });
  });

  /**
   * Build a large referee chain with all the known address
   */
  const mintTokenForEachUser = async () => {
    // Ensure when no referrer are in the chain, no reward are given
    for (const contentId of contentIds) {
      for (const addr of addrs) {
        // Update the share, and add some reward for this content
        await internalToken.mint(addr.address, buildFractionId(contentId, TOKEN_TYPE_GOLD), 5);
      }
    }

    for (const contentId of contentIds) {
      for (const tokenType of BUYABLE_TOKEN_TYPES) {
        // Update the share, and add some reward for this content
        await internalToken.mint(addr1.address, buildFractionId(contentId, tokenType), 10);
        await internalToken.mint(addr2.address, buildFractionId(contentId, tokenType), 10);
      }
    }
  };
});

/*
Base with lot of states : 
|  Rewarder             ·  payUser              ·     256 733  ·     621 326  ·      439 030  ·            2  ·       0.04  │

// With a few unchecked option mores
|  Rewarder             ·  payUser              ·     25 5948  ·     614 169  ·      435 059  ·            2  ·       0.04  │

// Increasing optimizer to 1 billions runs
|  Rewarder             ·  payUser              ·     25 5186  ·     610 317  ·         432752  ·            2  ·       0.06  │

// Switching from revert(xx) to revert error on base contract
|  Rewarder             ·  payUser              ·     255 071  ·     609 747  ·         432409  ·            2  ·       0.03  │

// Switching to error on all the rewarder contract (gaining 0.4kb on contract size)
|  Rewarder             ·  payUser              ·     255 233  ·     609 855  ·         432544  ·            2  ·       0.03  │

// Adding missing mint logic
|  Rewarder             ·  payUser              ·     255 547  ·     642 096  ·         448822  ·            2  ·       0.03  │ // With batching -> solution to adopt, with dynamic sized array
|  Rewarder             ·  payUser              ·     255 568  ·     643 796  ·         449682  ·            2  ·       0.03  │ // Without batching

// Switching to assembly for token type fetching
|  Rewarder             ·  payUser              ·     255 639  ·     643 836  ·         449738  ·            2  ·       0.05  │

// Back to simple if cascade
|  Rewarder             ·  payUser              ·     255 568  ·     643 796  ·         449682  ·            2  ·       0.05  │

// Optimising access of storage in loop
|  Rewarder             ·  payUser              ·     255 487  ·     632 106  ·         443797  ·            2  ·       0.05  │

// Otpimising int init, cachibng tpu for the complete loop
|  Rewarder             ·  payUser              ·     255 538  ·     621 526  ·         438532  ·            2  ·       0.66  │

// Same config as before, but with multi free token mint (and post mint call, here the lower cost)
|  Rewarder             ·  payUser              ·     124 903  ·     904 101  ·         529902  ·            6  ·       0.40  │

// Without fraktion mint (only 7k gain, potential gain of batched content id fetching is minimal)
|  Rewarder             ·  payUser              ·      69 519  ·     898 095  ·         312880  ·            6  ·       0.10  │

// Only free account with fraktion mint
 |  Rewarder             ·  payUser              ·     12 5111  ·     813 596  ·         455585  ·            5  ·       0.09  │

 // Some erc1155 error opti (gaining 1.2kb on size but loosing 600 gas)
  |  Rewarder             ·  payUser              ·     125 136  ·     814 051  ·         455805  ·            5  ·       0.07  │

// Merging check role and not paused into the same modifier (no impact, so useless)
|  Rewarder             ·  payUser              ·     125 136  ·     814 051  ·         455805  ·            5  ·       0.05  │


// Base : 
|  Rewarder             ·  payUser              ·     122977  ·     902974  ·         528534  ·            6  ·       0.08  │
|  SybelInternalTokens  ·  mint                 ·      84851  ·     222573  ·         102802  ·          500  ·       0.02  │

Switch from require to revert error on the push pull reward contract (gain 0.135 size per contract)
|  Rewarder             ·  payUser              ·     122 977  ·     902 974  ·         528 534  ·            6  ·       0.02  │
|  SybelInternalTokens  ·  mint                 ·      84 851  ·     222 573  ·         102 802  ·          500  ·       0.00  │

// Base : 
|  Rewarder             ·  payUser              ·     122 977  ·     902 134  ·         528394  ·            6  ·       0.04  │
|  SybelInternalTokens  ·  mint                 ·      84 795  ·     222 517  ·         102746  ·          500  ·       0.01  │

// Just moving it some vars : 
|  Rewarder             ·  payUser              ·     120 900  ·     881 294  ·         514116  ·            6  ·       0.02  │
|  SybelInternalTokens  ·  mint                 ·      84 795  ·     222 517  ·         102746  ·          500  ·       0.00  │

// Trying to switch listen var to uint256
|  Rewarder             ·  payUser              ·     120 894  ·     881 174  ·         514059  ·            6  ·       0.03  │

// After content pool and referral opti check
|  Rewarder             ·  payUser              ·     120 817  ·     879 299  ·         513550  ·            6  ·       0.04  │

// Switch listener badge to uint256
|  Rewarder             ·  payUser              ·     120 783  ·     879 265  ·         513516  ·            6  ·       0.06  │

// Big refacto from scratch of the payUser function
|  Rewarder             ·  payUser              ·     116 127  ·     758 419  ·         432194  ·            6  ·       0.03  │

// Testing gain without memory struct to store var (gaining 2k gas)
|  Rewarder             ·  payUser              ·     115 883  ·     756 416  ·         431153  ·            6  ·       0.02  │

// Testing gain with unsafe wad mul div down on single op
|  Rewarder             ·  payUser              ·     115 805  ·     756 338  ·         431075  ·            6  ·       0.03  │

// Adding WaD in the earning factor computation
|  Rewarder             ·  payUser              ·     115 805  ·     756 338  ·         431075  ·            6  ·       0.03  │

// Removing last trace of uint96
|  Rewarder             ·  payUser              ·     115 790  ·     756 038  ·         430933  ·            6  ·       0.03  │

// Performing total mints cost in unchecked block (since we havn't overflow during the previous computation, we are good)
|  Rewarder             ·  payUser              ·     115 588  ·     755 836  ·         430731  ·            6  ·       0.03  │

// Test without content and referral pool call (potential gain = 120k gas)
|  Rewarder             ·  payUser              ·     115 981  ·     630073  ·         401735  ·            6  ·       0.03  │

// Without external calls mint and content / referral pool (gain approx 200k max) :
|  Rewarder             ·  payUser              ·      88 745  ·     568 483  ·         345450  ·            6  ·       0.02  │

// New refactored base : 
|  Rewarder             ·  payUser              ·     115563  ·     755336  ·         430493  ·            6  ·       0.03  │

*/

/**
 * TODO : Solmate / UDS contract lookup
 *
 *  => https://github.com/transmissions11/solmate
 *  => https://github.com/0xPhaze/UDS -> Other upgradeable pattern, prevent memory clash,
 *
 * TODO : Foundry, is it really better ? Deploy and test transpilation ??
 *
 *  => https://github.com/foundry-rs/foundry
 *
 * Really faster but not ready for production yet
 */
