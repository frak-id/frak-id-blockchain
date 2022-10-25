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
import { buildFractionId, TOKEN_TYPE_COMMON, TOKEN_TYPE_DIAMOND, TOKEN_TYPE_GOLD } from "../../scripts/utils/mathUtils";

const REVOCABLE_GROUP = 1;
const NON_REVOCABLE_GROUP = 2;
const INITIAL_DROP_GROUP = 3;
const groupIds = [REVOCABLE_GROUP, NON_REVOCABLE_GROUP, INITIAL_DROP_GROUP];

const INEXISTANT_GROUP = 100;

const GROUP_CAP = BigNumber.from(10).pow(10);

describe("Rewarder", () => {
  let sybelToken: SybelToken;
  let internalToken: SybelInternalTokens;
  let listenerBadges: ListenerBadges;
  let contentBadges: ContentBadges;
  let referral: Referral;
  let contentPool: ContentPoolMultiContent;
  let rewarder: Rewarder;

  let contentId: BigNumber;

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    internalToken = await deployContract("SybelInternalTokens");
    listenerBadges = await deployContract("ListenerBadges");
    contentBadges = await deployContract("ContentBadges");
    referral = await deployContract("Referral", [sybelToken.address]);
    contentPool = await deployContract("ContentPoolMultiContent", [sybelToken.address]);
    rewarder = await deployContract("Rewarder", [
      sybelToken.address,
      internalToken.address,
      listenerBadges.address,
      contentBadges.address,
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

    // Mint a few contents
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);

    // Perform a mint and we will use this one as content id reference
    const mintEventTxReceipt = await internalToken.mintNewContent(addr1.address);

    // Extract the content id from mint tx
    const mintReceipt = await mintEventTxReceipt.wait();
    const ownerUpdateEvent = mintReceipt.events?.filter(contractEvent => {
      return contractEvent.event == "ContentOwnerUpdated";
    })[0] as ContentOwnerUpdatedEvent;
    if (!ownerUpdateEvent || !ownerUpdateEvent.args) throw new Error("Unable to find creation event");
    contentId = ownerUpdateEvent.args.id;
  });

  describe.only("Base reward", () => {
    it("Reward with free account", async () => {
      // TODO : Should be ko if the podcast isn't existing
      // TODO : We are failing but on the owner address fetching, not goood, should failed before
      await rewarder.payUser(addr1.address, [contentId], [100]);
      // This other run should cost less money since the free fraktion is already minted
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
      await rewarder.payUser(addr1.address, [contentId], [100]);
    });
    it.only("Reward with payed account", async () => {
      await internalToken.setSupplyBatch(
        [
          buildFractionId(contentId, TOKEN_TYPE_DIAMOND),
          buildFractionId(contentId, TOKEN_TYPE_COMMON),
          buildFractionId(contentId, TOKEN_TYPE_GOLD),
        ],
        [10000, 10000, 1000],
      );
      await internalToken.mint(addr2.address, buildFractionId(contentId, TOKEN_TYPE_DIAMOND), 10);
      await internalToken.mint(addr2.address, buildFractionId(contentId, TOKEN_TYPE_COMMON), 10);
      await internalToken.mint(addr2.address, buildFractionId(contentId, TOKEN_TYPE_GOLD), 10);
      // Rewarder with only one payed fraktion
      await rewarder.payUser(addr2.address, [contentId], [100]);
      await rewarder.payUser(addr2.address, [contentId], [100]);
      await rewarder.payUser(addr2.address, [contentId], [100]);
      await rewarder.payUser(addr2.address, [contentId], [100]);
      // |  Rewarder             ·  payUser              ·          -  ·          -  ·      277550  ·            1  ·       0.02  │
      await internalToken.mint(addr1.address, buildFractionId(contentId, TOKEN_TYPE_GOLD), 10);

      const maxIteration = 50;
      for (let index = 0; index < maxIteration; index++) {
        console.log(`iteration ${index}`);
        await internalToken.mint(addr2.address, buildFractionId(contentId, TOKEN_TYPE_COMMON), 10);
        await rewarder.payUser(addr2.address, [contentId, contentId, contentId], [100, 100, 100]);
        await internalToken.mint(addr1.address, buildFractionId(contentId, TOKEN_TYPE_DIAMOND), 10);
        await rewarder.payUser(addr2.address, [contentId, contentId, contentId], [100, 100, 100]);
        await internalToken.mint(_owner.address, buildFractionId(contentId, TOKEN_TYPE_GOLD), 10);
        await rewarder.payUser(addr2.address, [contentId, contentId, contentId], [100, 100, 100]);
      }
    });
  });
});
