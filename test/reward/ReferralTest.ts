// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { rewarderRole } from "../../scripts/utils/roles";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { Referral } from "../../types/contracts/reward/Referral";
import { expect } from "chai";
import { address0 } from "../utils/test-utils";
import { BigNumber } from "ethers";
import { ReferralPool } from "../../types/contracts/reward/pool/ReferralPool";

// Build our initial reward
const baseReward = BigNumber.from(10).pow(16); // So 0.001 frk

describe.only("Referral", () => {
  let sybelToken: SybelToken;
  let referral: ReferralPool;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    referral = await deployContract("ReferralPool", [sybelToken.address]);

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

// Base (with already a few opti) :
// |  ReferralPool  ·  payAllReferer  ·      34026  ·     521 556  ·      205568  ·            3  ·       0.03  │
// Base (with unchecked require on the user) :
// |  ReferralPool  ·  payAllReferer  ·      34026  ·     520 926  ·      205347  ·            3  ·       0.04  │
// With uncheck on the user address, and on the founds adding
// |  ReferralPool  ·  payAllReferer  ·      34026  ·     515 454  ·      203421  ·            3  ·       0.06  │
// With uncheck inside the pool iteration
// |  ReferralPool  ·  payAllReferer  ·      33990  ·     509 244  ·      201213  ·            3  ·       0.06  │
// Adding min amount check
// |  ReferralPool  ·  payAllReferer  ·      33990  ·     509 280  ·      201237  ·            3  ·       0.04  │
// With IR and CSE compilation
// |  ReferralPool  ·  payAllReferer  ·      33754  ·     507 442  ·      200437  ·            3  ·       0.04  │
// With IR and without CSE compilation
// |  ReferralPool  ·  payAllReferer  ·      33754  ·     507 442  ·      200437  ·            3  ·       0.09  │
// Without index on event
// |  ReferralPool  ·  payAllReferer  ·      33769  ·     503 773  ·      199158  ·            3  ·       2.30  │
// Without calling addFunds, all in the same unchecked block
// |  ReferralPool  ·  payAllReferer  ·      33760  ·     503 548  ·      199073  ·            3  ·       0.42  │
// Calling addFunds inside the unchecked block
// |  ReferralPool  ·  payAllReferer  ·      33752  ·     504 206  ·      199299  ·            3  ·       0.18  │
// Without copying the storage array
// |  ReferralPool  ·  payAllReferer  ·      33757  ·     504 895  ·      199545  ·            3  ·       0.12  │
// Reputting addfunds unchecked block
// |  ReferralPool  ·  payAllReferer  ·      33769  ·     503 773  ·      199158  ·            3  ·       0.20  │
// With 15 max depth
// |  ReferralPool  ·  payAllReferer  ·      33792  ·     426 532  ·      173449  ·            3  ·       0.08  │
// With 10 max depth
// |  ReferralPool  ·  payAllReferer  ·      33792  ·     295 652  ·      129822  ·            3  ·       0.05  │
// With 10 max depth, and 5000 optimizer run
// |  ReferralPool  ·  payAllReferer  ·      33768  ·     295 598  ·      129 787  ·            3  ·       0.05  │
// With 10 max depth, 5000runs, and some reward already existing (some important is the moy)
// |  ReferralPool  ·  payAllReferer  ·      33 768  ·     295 598  ·      126 544  ·            8  ·       0.04  │
// |  ReferralPool  ·  userReferred   ·      58 490  ·      96 961  ·       59 512  ·           38  ·       0.02  │
// With 10 max depth, 1000runs
// |  ReferralPool  ·  payAllReferer  ·      33 792  ·     295 652  ·      126 591  ·            8  ·       0.02  │
// |  ReferralPool  ·  userReferred   ·      58 517  ·      96 988  ·       59 539  ·           38  ·       0.01  │
// With 10 max depth, 1000runs, with optimizer default settings, and without IR
// |  ReferralPool  ·  payAllReferer  ·      34 027  ·     296 573  ·      127 349  ·            8  ·       0.02  │
// |  ReferralPool  ·  userReferred   ·      58 731  ·      98 239  ·       59 780  ·           38  ·       0.01  │
// With 10 max depth, 1000runs, with optimizercustom config and without IR
// |  ReferralPool  ·  payAllReferer  ·      34 432  ·     301 572  ·      131 257  ·            8  ·       0.03  │
// |  ReferralPool  ·  userReferred   ·      59 343  ·     100 415  ·       60 433  ·           38  ·       0.01  │
// With 10 max depth, 1000runs, with optimizer custom config, without literal and deduplicate) and without IR
// |  ReferralPool  ·  payAllReferer  ·      34 432  ·     301 572  ·      131 257  ·            8  ·       0.03  │
// |  ReferralPool  ·  userReferred   ·      59 343  ·     100 415  ·       60 433  ·           38  ·       0.01  │
// With 10 max depth, 1000runs, with all optimizer settings, and with IR
// |  ReferralPool  ·  payAllReferer  ·      33 792  ·     295 652  ·      126 591  ·            8  ·       0.01  │
// |  ReferralPool  ·  userReferred   ·      58 452  ·      96 923  ·       59 474  ·           38  ·       0.01  │
// With 10 max depth, 10k runs, with all optimizer settings, and with IR
// |  ReferralPool  ·  payAllReferer  ·      33 768  ·     295 598  ·       126 544  ·            8  ·       0.02  │
// |  ReferralPool  ·  userReferred   ·      58 425  ·      96 896  ·        59 447  ·           38  ·       0.01  │

// Without event emission (gaining 30K GAS !!!)
// |  ReferralPool  ·  payAllReferer  ·      33734  ·     474 788  ·      188935  ·            3  ·       0.10  │
// Without event and founds add (useless but to check what cost the more)
// |  ReferralPool  ·  payAllReferer  ·      33744  ·      75 378  ·       48408  ·            3  ·       0.44  │
