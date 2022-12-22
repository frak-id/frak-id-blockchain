// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { minterRole } from "../../scripts/utils/roles";
import { FrakToken, FrakTreasuryWallet } from "../../types";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { address0 } from "../utils/test-utils";

describe.only("FrakTreasuryWallet", () => {
  let frakToken: FrakToken;
  let treasuryWallet: FrakTreasuryWallet;

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Deploy our frak contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy our frak token and vesting wallets
    frakToken = await deployContract("FrakToken", [addr2.address]);
    treasuryWallet = await deployContract("FrakTreasuryWallet", [frakToken.address]);

    // Grant the minter role to the vesting wallet factory
    await frakToken.grantRole(minterRole, treasuryWallet.address);
  });

  describe("Transfer test", () => {
    it("Can't transfer to the 0 address", async () => {
      await expect(treasuryWallet.transfer(address0, 1)).to.be.reverted;
    });
    it("Can't transfer more than 500k frk", async () => {
      await expect(treasuryWallet.transfer(addr2.address, BigNumber.from(10).pow(18).mul(500_001))).to.be.reverted;
    });
    it("Can transfer less than 500k frk and auto mint", async () => {
      await expect(treasuryWallet.transfer(addr2.address, BigNumber.from(10).pow(18).mul(500_000))).to.not.be.reverted;
      expect(await frakToken.balanceOf(addr2.address)).to.eq(BigNumber.from(10).pow(18).mul(500_000))
    });
    it("Can handle empty mint amount if token transfered", async () => {
      // Transfer a total of 330_000 fkr tokens
      let totalToMint = BigNumber.from(10).pow(18).mul(330).mul(1_000_000)
      const mintPerIteration = BigNumber.from(10).pow(18).mul(500_000)
      do {
        await treasuryWallet.transfer(addr2.address, mintPerIteration);
        totalToMint = totalToMint.sub(mintPerIteration)
      } while (totalToMint.gt(0))
      // Can't auto transfer
      await expect(treasuryWallet.transfer(addr2.address, mintPerIteration)).to.be.reverted;
      await frakToken.mint(treasuryWallet.address, 100);
      // Can transfer all the remaining balance
      console.log(await frakToken.balanceOf(treasuryWallet.address))
      // Can't transfer more than the balance
      await expect(treasuryWallet.transfer(addr2.address, 101)).to.be.reverted;
      await expect(treasuryWallet.transfer(addr2.address, 100)).to.not.be.reverted;
    });
  });
  // Test the roles
  describe("Minting roles", () => {
    testRoles(
      () => treasuryWallet,
      () => addr1,
      minterRole,
      [
        async () => {
          // Can't add vesting groyp if paused
          await treasuryWallet.connect(addr1).transfer(addr2.address, 10);
        },
      ],
    );
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => treasuryWallet,
      () => addr1,
      [
        async () => {
          // Can't transfer if paused
          await treasuryWallet.transfer(addr1.address, 10);
        }
      ],
    );
  });
});
