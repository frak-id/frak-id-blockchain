// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { adminRole, minterRole, rewarderRole, vestingCreatorRole, vestingManagerRole } from "../../scripts/utils/roles";
import { ContentBadges } from "../../types/contracts/badges/payment/ContentBadges";
import { ListenerBadges } from "../../types/contracts/badges/payment/ListenerBadges";
import { ContentOwnerUpdatedEvent, SybelInternalTokens } from "../../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { ContentPoolMultiContent } from "../../types/contracts/reward/ContentPoolMultiContent";
import { Referral } from "../../types/contracts/reward/Referral";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { address0, getTimestampInAFewMoment } from "../utils/test-utils";
import { Rewarder } from "../../types/contracts/reward/Rewarder";
import {
  buildFractionId,
  BUYABLE_TOKEN_TYPES,
  TOKEN_TYPE_COMMON,
  TOKEN_TYPE_DIAMOND,
  TOKEN_TYPE_GOLD,
} from "../../scripts/utils/mathUtils";
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
      for (let typeIndex = 0; typeIndex < BUYABLE_TOKEN_TYPES.length; typeIndex++) {
        const tokenType = BUYABLE_TOKEN_TYPES[typeIndex];
        await internalToken.setSupplyBatch([buildFractionId(mintedTokenId, tokenType)], [100000]);
      }
    }
  });

  describe("Base reward", () => {
    it("Reward with free account", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, [contentIds[0]], [100]);
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
