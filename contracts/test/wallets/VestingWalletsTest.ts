// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { BigNumber, ContractTransaction, utils } from "ethers";

import { SybelToken } from "../../types/contracts/tokens/SybelToken";
import { VestingWallets } from "../../types/contracts/wallets/VestingWallets";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "../../scripts/utils/deploy";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { adminRole, pauserRole } from "../../scripts/utils/roles";

const GROUP_INVESTOR_ID = 1;
const GROUP_TEAM_ID = 2;
const GROUP_PRE_SALES_1_ID = 10;
const GROUP_PRE_SALES_2_ID = 11;
const GROUP_PRE_SALES_3_ID = 12;
const GROUP_PRE_SALES_4_ID = 13;

describe.skip("VestingWallets", () => {
  let vestingWallets: VestingWallets;
  let sybelToken: SybelToken;
  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let _addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Our investor group
  let investorGroup: VestingWallets.VestingGroupStruct;

  // Deploy our sybel contract
  beforeEach(async function () {
    [_owner, addr1, _addr2, ..._addrs] = await ethers.getSigners();

    // Deploy our sybel token and vesting wallets
    sybelToken = await deployContract("SybelToken");
    vestingWallets = await deployContract("VestingWallets", [sybelToken.address]);

    // Grant the minter role to the vesting wallets
    const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
    await sybelToken.grantRole(minterRole, vestingWallets.address);

    // Find the investor group
    investorGroup = await vestingWallets.getVestingGroup(GROUP_INVESTOR_ID);
  });

  // Check all the add investor possibility
  describe("Investors", () => {
    it("Can add a new investor, and release founds via admin", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);

      const tx = await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);

      // Get the current timestamp
      await updateTimestampToEndOfInvestorDuration(tx);

      // Try to release the amount

      await vestingWallets["release(address)"](addr1.address);
      const newdAddr1Balance = await sybelToken.balanceOf(addr1.address);

      // Ensure the addre 1 can release 50 sybl
      expect(newdAddr1Balance).to.equal(oldAddr1Balance.add(50));
      expect(await vestingWallets["releasedAmount(address)"](addr1.address)).to.equal(50);
    });

    it("Can add a new investor, and release founds itself", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);

      const tx = await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);

      // Get the current timestamp
      await updateTimestampToEndOfInvestorDuration(tx);

      // Try to release the amount

      await vestingWallets.connect(addr1)["release()"]();
      const newdAddr1Balance = await sybelToken.balanceOf(addr1.address);

      // Ensure the addre 1 can release 50 sybl
      expect(newdAddr1Balance).to.equal(oldAddr1Balance.add(50));
      expect(await vestingWallets.connect(addr1)["releasedAmount()"]()).to.equal(50);
    });

    it("Can add a new investor on multiple vesting group", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);

      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);
      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_TEAM_ID);
      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_PRE_SALES_1_ID);
      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_PRE_SALES_2_ID);
      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_PRE_SALES_3_ID);
      const tx = await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_PRE_SALES_4_ID);

      // Check the number of vesting wallets for the user
      const wallets = await vestingWallets.getVestingWallet(addr1.address);
      expect(wallets.length).to.equal(6);

      // Get the current timestamp
      await updateTimestampToEndOfInvestorDuration(tx);

      // Try to release the amount
      await vestingWallets.connect(addr1)["release()"]();
      const newdAddr1Balance = await sybelToken.balanceOf(addr1.address);

      // Ensure the addre 1 can release 300 sybl
      expect(newdAddr1Balance).to.equal(oldAddr1Balance.add(300));
      expect(await vestingWallets.connect(addr1)["releasedAmount()"]()).to.equal(300);
    });

    it("Can't exceed group cap", async () => {
      const exceedAmount = BigNumber.from(await investorGroup.rewardCap).add(1);
      await expect(vestingWallets.addVestingWallet(addr1.address, exceedAmount, GROUP_INVESTOR_ID)).to.be.reverted;
    });

    it("Don't create two vesting wallet for a given invester", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);

      // Create a first vesting wallet
      const tx = await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);

      // Got at the end of the delay
      await updateTimestampToEndOfInvestorDuration(tx);

      // Add 50 more token
      await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);

      // Try to release the amount
      await vestingWallets["release(address)"](addr1.address);
      const newdAddr1Balance = await sybelToken.balanceOf(addr1.address);

      // Ensure the addre 1 can release 100 sybl
      expect(newdAddr1Balance).to.equal(oldAddr1Balance.add(100));
      expect(await vestingWallets["releasedAmount(address)"](addr1.address)).to.equal(100);
    });
  });

  describe("Groups", () => {
    it("Can't create two group for the same id", async () => {
      // Add a new vesting group
      await vestingWallets.addVestingGroup(13, 10, 10, 10);
      // Add another one with the same id
      await expect(vestingWallets.addVestingGroup(13, 10, 10, 10)).to.be.reverted;
    });
    it("Can't exceed contract vesting cap", async () => {
      // Add another one with the same id
      await expect(vestingWallets.addVestingGroup(13, BigNumber.from(10).pow(18).mul(2_000_000_000), 10, 10)).to.be
        .reverted;
    });
  });

  // Check the roles
  describe("Admin roles", () => {
    testRoles(
      () => vestingWallets,
      () => addr1,
      adminRole,
      [
        async () => {
          await vestingWallets.connect(addr1).addVestingGroup(13, 10, 10, 10);
        },
      ],
    );
  });
  describe("Pauser roles", () => {
    testRoles(
      () => vestingWallets,
      () => addr1,
      pauserRole,
      [
        async () => {
          await vestingWallets.connect(addr1).pause();
          await vestingWallets.connect(addr1).unpause();
        },
      ],
    );
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => vestingWallets,
      () => addr1,
      [
        async () => {
          await vestingWallets.addVestingGroup(13, 10, 10, 10);
        },
        async () => {
          await vestingWallets.addVestingWallet(addr1.address, 50, GROUP_INVESTOR_ID);
        },
      ],
    );
  });

  async function updateTimestampToEndOfInvestorDuration(tx: ContractTransaction) {
    // Wait for the tx to be mined
    await tx.wait();
    const txMined = await ethers.provider.getTransaction(tx.hash);
    const blockTimestamp = (await ethers.provider.getBlock(txMined.blockHash!)).timestamp;
    // Get the investor group duration
    const newTimestamp = BigNumber.from(blockTimestamp)
      .add(await investorGroup.duration)
      .add(await investorGroup.delay)
      .toNumber();
    // Increase the blockchain timestamp
    await ethers.provider.send("evm_mine", [newTimestamp]);
  }
});
