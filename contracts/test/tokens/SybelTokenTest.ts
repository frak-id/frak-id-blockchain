// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { BigNumber, utils } from "ethers";

import { SybelToken } from "../../typechain-types/contracts/tokens/SybelToken";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "../utils/deploy";
import { testRoles } from "../utils/test-roles";
import { testPauses } from "../utils/test-pauses";
import { minterRole, pauserRole } from "../utils/roles";

describe("SybelToken", () => {
  let sybelToken: SybelToken;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy our sybel token
    sybelToken = await deployContract("SybelToken");

    // Mint a fiew sybl to the owner and first addr
    const syblToMint = BigNumber.from(10).pow(18).mul(50);
    await sybelToken.mint(owner.address, syblToMint);
    await sybelToken.mint(addr1.address, syblToMint);
  });

  // Check the transactions
  describe("Transactions", () => {
    it("Should transfer tokens between owner and accounts", async () => {
      // Perform the transfer of 50 sybl
      const previousOwnerBalance = await sybelToken.balanceOf(owner.address);
      const previousAddr2Balance = await sybelToken.balanceOf(addr2.address);
      await sybelToken.transfer(addr2.address, 50);

      // Ensure the funds are transfered
      const newOwnerBalance = await sybelToken.balanceOf(owner.address);
      const newAddr2Balance = await sybelToken.balanceOf(addr2.address);
      expect(newOwnerBalance).to.equal(previousOwnerBalance.sub(50));
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });

    it("Should transfer tokens between regular accounts", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await sybelToken.balanceOf(addr1.address);
      const previousAddr2Balance = await sybelToken.balanceOf(addr2.address);
      await sybelToken.connect(addr1).transfer(addr2.address, 50);

      // Ensure the funds are transfered
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      const newAddr2Balance = await sybelToken.balanceOf(addr2.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });
    it("Can approove another wallet to perform a transfer", async () => {
      // Perform the transfer of 50 sybl
      const previousOwnerBalance = await sybelToken.balanceOf(owner.address);
      const previousAddr1Balance = await sybelToken.balanceOf(addr1.address);
      // Approove the addr2 to spend tokens
      await sybelToken.connect(addr1).approve(addr2.address, 50);

      // Ensure the allowance is saved
      const addresse2Allowance = await sybelToken.allowance(addr1.address, addr2.address);
      expect(addresse2Allowance).to.equal(BigNumber.from(50));

      // Ask the addr2 token to send founds
      await sybelToken.connect(addr2).transferFrom(addr1.address, owner.address, 50);

      // Ensure the addr2 can't perform more transfer
      await expect(sybelToken.connect(addr2).transferFrom(addr1.address, owner.address, 50)).to.be.reverted;

      // Ensure the funds are transfered
      const newOwnerBalance = await sybelToken.balanceOf(owner.address);
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newOwnerBalance).to.equal(previousOwnerBalance.add(50));
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
    });

    it("User can burn token", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await sybelToken.balanceOf(addr1.address);
      await sybelToken.connect(addr1).burn(50);

      // Ensure the funds are transfered
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
    });

    it("Can't transfer tokens between two accounts without approval for user", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await sybelToken.balanceOf(addr1.address);
      const previousAddr2Balance = await sybelToken.balanceOf(addr2.address);

      // Try to transfer the token
      await expect(sybelToken.connect(addr1).transferFrom(addr1.address, addr2.address, 50)).to.be.reverted;

      // Ensure the funds arn't transfered
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      const newAddr2Balance = await sybelToken.balanceOf(addr2.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance);
      expect(newAddr2Balance).to.equal(previousAddr2Balance);
    });
  });

  // Check the transactions
  describe("Mint", () => {
    it("Owner can perform token mint", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr2Balance = await sybelToken.balanceOf(addr2.address);
      await sybelToken.mint(addr2.address, 50);

      // Ensure the funds are transfered
      const newAddr2Balance = await sybelToken.balanceOf(addr2.address);
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });
    it("Mint cap can't be exceeded", async () => {
      // Perform the mint of the cap + 50
      await expect(sybelToken.mint(addr2.address, BigNumber.from(10).pow(18).mul(3000000000).add(50))).to.be.reverted;
    });
    it("User can't perform token mint", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr2Balance = await sybelToken.balanceOf(addr2.address);

      await expect(sybelToken.connect(addr1).mint(addr2.address, 50)).to.be.reverted;

      // Ensure the funds are transfered
      const newAddr2Balance = await sybelToken.balanceOf(addr2.address);
      expect(newAddr2Balance).to.equal(previousAddr2Balance);
    });
  });

  // Check the Roles managment
  describe("Minter roles", () => {
    testRoles(
      () => sybelToken,
      () => addr1,
      minterRole,
      [
        async () => {
          await sybelToken.connect(addr1).mint(addr2.address, 50);
        },
      ],
    );
  });
  describe("Pauser roles", () => {
    testRoles(
      () => sybelToken,
      () => addr1,
      pauserRole,
      [
        async () => {
          await sybelToken.connect(addr1).pause();
          await sybelToken.connect(addr1).unpause();
        },
      ],
    );
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => sybelToken,
      () => addr1,
      [
        async () => {
          await sybelToken.transfer(addr1.address, 50);
        },
        async () => {
          await sybelToken.connect(addr1).transfer(owner.address, 50);
        },
        async () => {
          await sybelToken.mint(addr1.address, 50);
        },
      ],
    );
  });
});
