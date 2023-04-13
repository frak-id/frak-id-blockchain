// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { BUYABLE_TOKEN_TYPES, TOKEN_TYPE_GOLD, buildFractionId } from "../../scripts/utils/mathUtils";
import { minterRole, rewarderRole, tokenContractRole } from "../../scripts/utils/roles";
import { ContentPool, FrakToken, FraktionTokens, ReferralPool, Rewarder } from "../../types";
import { ContentOwnerUpdatedEvent } from "../../types/contracts/tokens/FraktionTokens";

describe("Rewarder", () => {
  let frakToken: FrakToken;
  let fraktionTokens: FraktionTokens;
  let referral: ReferralPool;
  let contentPool: ContentPool;
  let rewarder: Rewarder;

  const contentIds: BigNumber[] = [];
  const ccus: number[] = [];

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our frak contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    frakToken = await deployContract("FrakToken", [addr2.address]);
    fraktionTokens = await deployContract("FraktionTokens", ["url"]);
    referral = await deployContract("ReferralPool", [frakToken.address]);
    contentPool = await deployContract("ContentPool", [frakToken.address]);
    rewarder = await deployContract("Rewarder", [
      frakToken.address,
      fraktionTokens.address,
      contentPool.address,
      referral.address,
      frakToken.address,
    ]);

    // Mint the initial supply
    await frakToken.mint(rewarder.address, BigNumber.from(10).pow(18).mul(1_000_000_000));

    // Grant the minter role on the rewarder contract for our nft and frak
    await fraktionTokens.grantRole(minterRole, rewarder.address);
    await frakToken.grantRole(minterRole, rewarder.address);

    // Grant the rewarder role to the referral contract
    await referral.grantRole(rewarderRole, rewarder.address);
    await contentPool.grantRole(rewarderRole, rewarder.address);

    // Grant the token contract role to the content pool
    await contentPool.grantRole(tokenContractRole, fraktionTokens.address);

    // Setup the callback on the internal tokens for our content pool
    await fraktionTokens.registerNewCallback(contentPool.address);

    for (let index = 0; index < 5; index++) {
      // Perform a mint and we will use this one as content id reference
      const mintEventTxReceipt = await fraktionTokens.mintNewContent(addr1.address);

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
        await fraktionTokens.setSupply(buildFractionId(mintedTokenId, tokenType), 100000);
      }
    }
  });

  describe("Base reward", () => {
    it("Single free reward account", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, 1, [contentIds[0]], [100]);
      // Going throught it a second time to prevent fraktion mint
      await rewarder.payUser(addr1.address, 1, [contentIds[0]], [100]);
    });
    it("Tone of free reward", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, 1, contentIds, ccus);

      // Perform the run a second time so we don't go past the free fraktion mint
      await rewarder.payUser(addr1.address, 1, contentIds, ccus);
    });
    it("Multiple free reward", async () => {
      // TODO : Add some check on each pool, on the amount minted etc
      await rewarder.payUser(addr1.address, 1, contentIds, ccus);
    });
    it("Reward with payed account", async () => {
      // Mint token for each user
      await mintTokenForEachUser();
      // Rewarder with only one payed fraktion
      await rewarder.payUser(addr1.address, 1, contentIds, ccus);
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
        await fraktionTokens.mint(addr.address, buildFractionId(contentId, TOKEN_TYPE_GOLD), 5);
      }
    }

    for (const contentId of contentIds) {
      for (const tokenType of BUYABLE_TOKEN_TYPES) {
        // Update the share, and add some reward for this content
        await fraktionTokens.mint(addr1.address, buildFractionId(contentId, tokenType), 10);
        await fraktionTokens.mint(addr2.address, buildFractionId(contentId, tokenType), 10);
      }
    }
  };
});
