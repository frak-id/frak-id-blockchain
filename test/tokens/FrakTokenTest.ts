// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { minterRole, pauserRole } from "../../scripts/utils/roles";
import { FrakToken } from "../../types";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";

describe("FrakToken", () => {
  let frakToken: FrakToken;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy our sybel token
    frakToken = await deployContract("FrakToken", [addr2.address]);

    // Mint a fiew sybl to the owner and first addr
    const frkToMint = BigNumber.from(10).pow(18).mul(50);
    await frakToken.mint(owner.address, frkToMint);
    await frakToken.mint(addr1.address, frkToMint);
  });

  // Check the transactions
  describe("Transactions", () => {
    it("Should transfer tokens between owner and accounts", async () => {
      // Perform the transfer of 50 sybl
      const previousOwnerBalance = await frakToken.balanceOf(owner.address);
      const previousAddr2Balance = await frakToken.balanceOf(addr2.address);
      await frakToken.transfer(addr2.address, 50);

      // Ensure the funds are transfered
      const newOwnerBalance = await frakToken.balanceOf(owner.address);
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newOwnerBalance).to.equal(previousOwnerBalance.sub(50));
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });

    it("Should transfer tokens between regular accounts", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await frakToken.balanceOf(addr1.address);
      const previousAddr2Balance = await frakToken.balanceOf(addr2.address);
      await frakToken.connect(addr1).transfer(addr2.address, 50);

      // Ensure the funds are transfered
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });
    it("Can approove another wallet to perform a transfer", async () => {
      // Perform the transfer of 50 sybl
      const previousOwnerBalance = await frakToken.balanceOf(owner.address);
      const previousAddr1Balance = await frakToken.balanceOf(addr1.address);
      // Approove the addr2 to spend tokens
      await frakToken.connect(addr1).approve(addr2.address, 50);

      // Ensure the allowance is saved
      const addresse2Allowance = await frakToken.allowance(addr1.address, addr2.address);
      expect(addresse2Allowance).to.equal(BigNumber.from(50));

      // Ask the addr2 token to send founds
      await frakToken.connect(addr2).transferFrom(addr1.address, owner.address, 50);

      // Ensure the addr2 can't perform more transfer
      await expect(frakToken.connect(addr2).transferFrom(addr1.address, owner.address, 50)).to.be.reverted;

      // Ensure the funds are transfered
      const newOwnerBalance = await frakToken.balanceOf(owner.address);
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newOwnerBalance).to.equal(previousOwnerBalance.add(50));
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
    });

    it("User can burn token", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await frakToken.balanceOf(addr1.address);
      await frakToken.connect(addr1).burn(50);

      // Ensure the funds are transfered
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance.sub(50));
    });

    it("Can't transfer tokens between two accounts without approval for user", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr1Balance = await frakToken.balanceOf(addr1.address);
      const previousAddr2Balance = await frakToken.balanceOf(addr2.address);

      // Try to transfer the token
      await expect(frakToken.connect(addr1).transferFrom(addr1.address, addr2.address, 50)).to.be.reverted;

      // Ensure the funds arn't transfered
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newAddr1Balance).to.equal(previousAddr1Balance);
      expect(newAddr2Balance).to.equal(previousAddr2Balance);
    });
  });

  // Check the transactions
  describe("Mint", () => {
    it("Owner can perform token mint", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr2Balance = await frakToken.balanceOf(addr2.address);
      await frakToken.mint(addr2.address, 50);

      // Ensure the funds are transfered
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newAddr2Balance).to.equal(previousAddr2Balance.add(50));
    });
    it("Mint cap can't be exceeded", async () => {
      // Perform the mint of the cap + 50
      await expect(frakToken.mint(addr2.address, BigNumber.from(10).pow(18).mul(3000000000).add(50))).to.be.reverted;
    });
    it("User can't perform token mint", async () => {
      // Perform the transfer of 50 sybl
      const previousAddr2Balance = await frakToken.balanceOf(addr2.address);

      await expect(frakToken.connect(addr1).mint(addr2.address, 50)).to.be.reverted;

      // Ensure the funds are transfered
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newAddr2Balance).to.equal(previousAddr2Balance);
    });
  });

  // Check the Roles managment
  describe("Minter roles", () => {
    testRoles(
      () => frakToken,
      () => addr1,
      minterRole,
      [
        async () => {
          await frakToken.connect(addr1).mint(addr2.address, 50);
        },
      ],
    );
  });
  describe("Pauser roles", () => {
    testRoles(
      () => frakToken,
      () => addr1,
      pauserRole,
      [
        async () => {
          await frakToken.connect(addr1).pause();
          await frakToken.connect(addr1).unpause();
        },
      ],
    );
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => frakToken,
      () => addr1,
      [
        async () => {
          await frakToken.mint(addr1.address, 50);
        },
      ],
    );
  });
});
