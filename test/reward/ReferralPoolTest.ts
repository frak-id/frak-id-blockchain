// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { rewarderRole } from "../../scripts/utils/roles";
import { FrakToken, ReferralPool } from "../../types";
import { address0 } from "../utils/test-utils";

// Build our initial reward
const baseReward = BigNumber.from(10).pow(16); // So 0.001 frk

describe("Referral Pool", () => {
  let frakToken: FrakToken;
  let referral: ReferralPool;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    frakToken = await deployContract("FrakToken", [addr2.address]);
    referral = await deployContract("ReferralPool", [frakToken.address]);

    // Grant the rewarder role to the referral contract
    await referral.grantRole(rewarderRole, owner.address);
  });

  describe("Adding referrer and reward", () => {
    it("Can't pay 0 address", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await expect(referral.payAllReferer(1, address0, 10)).to.be.reverted;
    });
    it("Can't pay 0 reward", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await expect(referral.payAllReferer(1, addr1.address, 0)).to.be.reverted;
    });
    it("No reward given if no referee", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await referral.payAllReferer(1, addr1.address, 10);
      const pendingReward = await referral.getAvailableFounds(addr1.address);
      expect(pendingReward).to.equal(BigNumber.from(0));
    });
    it("Can't referrer ourself", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await expect(referral.userReferred(1, addr1.address, addr1.address)).to.be.reverted;
    });
    it("Can't referrer 0 address", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await expect(referral.userReferred(1, addr1.address, address0)).to.be.reverted;
      await expect(referral.userReferred(1, address0, addr1.address)).to.be.reverted;
    });
    it("Can't crete referee chain", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await referral.userReferred(1, addr1.address, addr2.address);
      await referral.userReferred(1, addr2.address, owner.address);

      await expect(referral.userReferred(1, owner.address, addr1.address)).to.be.reverted;
      await expect(referral.userReferred(1, owner.address, addr2.address)).to.be.reverted;
      await expect(referral.userReferred(1, addr2.address, addr1.address)).to.be.reverted;
    });
    it("Create large referee chain", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await buildLargeRefereeChain();
      await expect(referral.userReferred(1, addrs[addrs.length - 1].address, addr1.address)).to.be.reverted;
    });
    it("Can pay simple reward", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await referral.userReferred(1, addr1.address, addr2.address);
      await referral.payAllReferer(1, addr1.address, baseReward);
      const pendingReward = await referral.getAvailableFounds(addr2.address);
      expect(pendingReward).to.equal(BigNumber.from(baseReward));
    });
    it("Can pay large referee chain", async () => {
      // Ensure when no referrer are in the chain, no reward are given
      await buildLargeRefereeChain();
      await referral.userReferred(1, addr2.address, addr1.address);
      await referral.payAllReferer(1, addr2.address, baseReward);

      let pendingAddr1Reward = await referral.getAvailableFounds(addr1.address);
      const pendingLastUserReward = await referral.getAvailableFounds(addrs[addrs.length - 1].address);

      expect(pendingAddr1Reward).to.equal(BigNumber.from(baseReward));
      expect(pendingLastUserReward).to.be.equal(BigNumber.from(0)); // Expect to be at 0 because too much depth

      // Relaunch a payment rounds
      await referral.payAllReferer(1, addr2.address, baseReward);
      await referral.payAllReferer(1, addr2.address, baseReward);
      await referral.payAllReferer(1, addr2.address, baseReward);
      await referral.payAllReferer(1, addr2.address, baseReward);
      await referral.payAllReferer(1, addr2.address, baseReward);

      pendingAddr1Reward = await referral.getAvailableFounds(addr1.address);
      expect(pendingAddr1Reward).to.equal(BigNumber.from(baseReward).mul(6));
    });
  });

  /**
   * Build a large referee chain with all the known address
   */
  const buildLargeRefereeChain = async () => {
    // Ensure when no referrer are in the chain, no reward are given
    for (let index = 0; index < addrs.length; index++) {
      // Get he previous array index
      const previousAddr = index == 0 ? addr1 : addrs[index - 1];
      const currentAddr = addrs[index];
      // Let the previous address be the referer of the current address
      await referral.userReferred(1, previousAddr.address, currentAddr.address);
    }
  };
});
