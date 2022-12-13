// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, ContractTransaction } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { adminRole, minterRole, pauserRole, vestingManagerRole } from "../../scripts/utils/roles";
import { FrakToken } from "../../types";
import { MultiVestingWallets, VestingCreatedEvent } from "../../types/contracts/wallets/MultiVestingWallets";
import { testRoles } from "../utils/test-roles";
import { address0, getTimestampInAFewMoment, updatToGivenTimestamp } from "../utils/test-utils";

const initialMintSupply = BigNumber.from(10).pow(18).mul(500_000_000);

describe("MultipleVestingWallets", () => {
  let multiVestingWallets: MultiVestingWallets;
  let frakToken: FrakToken;

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  beforeEach(async function () {
    [_owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy our sybel token and vesting wallets
    frakToken = await deployContract("FrakToken", [addr2.address]);
    multiVestingWallets = await deployContract("MultiVestingWallets", [frakToken.address]);

    // Grant the minter role to the vesting wallets
    await frakToken.grantRole(minterRole, multiVestingWallets.address);

    // Add some initial supply to our vesting group
    await frakToken.mint(multiVestingWallets.address, initialMintSupply);
  });

  describe("Faking ERC20", () => {
    it("Have all the properties for an erc20 token", async () => {
      // Get the name, symbol and decimals
      const name = await multiVestingWallets.name();
      const symbol = await multiVestingWallets.symbol();
      const decimals = await multiVestingWallets.decimals();

      expect(name).not.to.be.null;
      expect(symbol).to.equal("vFRK");
      expect(decimals).to.equal(await frakToken.decimals());
    });
  });

  // Checl all the creation capabilities
  describe("Vesting creation", () => {
    it("Can add a new vesting wallet, user release itself his founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await frakToken.balanceOf(addr1.address);
      // Get the current blockchain timestamp
      const startTimestamp = await getTimestampInAFewMoment();
      // Create the vest
      await multiVestingWallets.createVest(addr1.address, 100, 50, 100, startTimestamp, false);
      // Check the number of vesting the beneficiary add
      const balanceOfVest = await multiVestingWallets.balanceOf(addr1.address);
      expect(balanceOfVest).to.equal(100);
      // Check the number of vesting the beneficiary add
      const numberOfVest = await multiVestingWallets.ownedCount(addr1.address);
      expect(numberOfVest).to.equal(1);
      // Ensure the user can unlock the initial drop amount
      await updatToGivenTimestamp(startTimestamp);
      // Ensure the user can release his amount, and ensure his balance was updated
      await multiVestingWallets.connect(addr1).releaseAll();
      // Ensure the initial drop of the investor is unlockable
      let newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(50));
      // Wait for end of the cliff, and ensure the remaining amount can be unlocked
      await updatToGivenTimestamp(startTimestamp + 100);
      await multiVestingWallets.connect(addr1).releaseAll();
      newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(100));
    });
    it("Can add multiple vesting wallets, owner release user founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await frakToken.balanceOf(addr1.address);
      // Create the vest
      const startTimestamp = await getTimestampInAFewMoment();
      await multiVestingWallets.createVestBatch(
        [addr1.address, addr2.address, addr1.address],
        [100, 100, 100],
        [50, 50, 50],
        100,
        startTimestamp,
        false,
      );
      // Check the number of vesting the beneficiary add
      const balanceOfVest = await multiVestingWallets.balanceOf(addr1.address);
      expect(balanceOfVest).to.equal(200);
      // Check the number of vesting the beneficiary add
      const numberOfVestAddr1 = await multiVestingWallets.ownedCount(addr1.address);
      expect(numberOfVestAddr1).to.equal(2);
      // Check the number of vesting the beneficiary add
      const numberOfVestAddr2 = await multiVestingWallets.ownedCount(addr2.address);
      expect(numberOfVestAddr2).to.equal(1);
      // Got to the end of vesting
      await updatToGivenTimestamp(startTimestamp + 100);
      // Ensure the user can release his amount, and ensure his balance was updated
      await multiVestingWallets.releaseAllFor(addr1.address);
      // Get the original balance of an investor
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(200));
    });
    it("Can't create if past date", async () => {
      await expect(
        multiVestingWallets.createVest(addr1.address, 100, 10, 10, (await getTimestampInAFewMoment()) - 15, false),
      ).to.be.reverted;
    });
    it("Can't add single vesting wallet with 0 duration", async () => {
      // Try to create the vest
      await expect(multiVestingWallets.createVest(addr1.address, 100, 10, 0, await getTimestampInAFewMoment(), false))
        .to.be.reverted;
    });
    it("Can't add multiple vesting wallet with 0 delay and duration", async () => {
      // Try to create the vest
      await expect(
        multiVestingWallets.createVestBatch([addr1.address], [100], [10], 0, await getTimestampInAFewMoment(), false),
      ).to.be.reverted;
    });
    it("Can't add multiple vesting wallet with different sizes", async () => {
      // Try to create the vest
      await expect(
        multiVestingWallets.createVestBatch(
          [addr1.address],
          [100, 100],
          [10, 10],
          0,
          await getTimestampInAFewMoment(),
          false,
        ),
      ).to.be.reverted;
      await expect(
        multiVestingWallets.createVestBatch(
          [addr1.address],
          [100],
          [10, 10],
          0,
          await getTimestampInAFewMoment(),
          false,
        ),
      ).to.be.reverted;
    });
    it("Can't add batch with empty array", async () => {
      await expect(multiVestingWallets.createVestBatch([], [], [], 0, await getTimestampInAFewMoment(), false)).to.be
        .reverted;
    });
    it("Can't add vesting with initial drop larger than reward", async () => {
      // Try to create the vest
      await expect(multiVestingWallets.createVest(addr1.address, 100, 200, 10, await getTimestampInAFewMoment(), false))
        .to.be.reverted;
    });
    it("Can't add wallet hat exceed the balance of the adress", async () => {
      await multiVestingWallets.transferAvailableReserve(addr1.address);
      // Try to create the vest
      await expect(
        multiVestingWallets.createVest(
          addr1.address,
          initialMintSupply.add(1),
          1000,
          10,
          await getTimestampInAFewMoment(),
          false,
        ),
      ).to.be.reverted;
    });
    it("Can't add vesting to 0 address", async () => {
      await expect(multiVestingWallets.createVest(address0, 100, 10, 10, await getTimestampInAFewMoment(), false)).to.be
        .reverted;
    });
    it("Can't add with 0reward", async () => {
      await expect(multiVestingWallets.createVest(addr1.address, 0, 0, 10, await getTimestampInAFewMoment(), false)).to
        .be.reverted;
    });
    it("Can't exceed reward cap", async () => {
      await expect(
        multiVestingWallets.createVest(
          addr1.address,
          BigNumber.from(10).pow(18).mul(200_000_000).add(1),
          10,
          10,
          await getTimestampInAFewMoment(),
          false,
        ),
      ).to.be.reverted;
    });
  });

  // Checl all the transfer capabilities
  describe("Vesting transer", () => {
    it("Can transfer and unlock a vesting", async () => {
      // Get the original balance of an investor
      const oldAddr2Balance = await frakToken.balanceOf(addr2.address);
      // Get the current blockchain timestamp
      const startTimestamp = await getTimestampInAFewMoment();
      // Create the vest
      const createTx = await multiVestingWallets.createVest(addr1.address, 100, 0, 100, startTimestamp, false);
      const createEvent = await extractVestingCreatedEvent(createTx);
      // Extract the vest id from the create event
      const vestId = createEvent.args.id;
      // Transfer the vest id to addr2
      await multiVestingWallets.connect(addr1).transfer(addr2.address, vestId);
      // Ensure the user can unlock the initial drop amount
      await updatToGivenTimestamp(startTimestamp + 100);
      // Ensure addr2 can release funds, and his balance is updated
      await multiVestingWallets.connect(addr2).release(vestId);
      const newAddr2Balance = await frakToken.balanceOf(addr2.address);
      expect(newAddr2Balance).to.equal(oldAddr2Balance.add(100));
    });
    it("Can't transfer 0 address ", async () => {
      // Get the current blockchain timestamp
      const startTimestamp = await getTimestampInAFewMoment();
      // Create the vest
      const createTx = await multiVestingWallets.createVest(addr1.address, 100, 0, 100, startTimestamp, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      // Extract the vest id from the create event
      const vestId = createEvent.args.id;
      // Transfer the vest id to addr2
      await expect(multiVestingWallets.connect(addr1).transfer(address0, vestId)).to.be.reverted;
    });
    it("Can't transfer a revoked vesting", async () => {
      // Get the current blockchain timestamp
      const startTimestamp = await getTimestampInAFewMoment();
      // Create the vest
      const createTx = await multiVestingWallets.createVest(addr1.address, 100, 0, 100, startTimestamp, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      // Extract the vest id from the create event
      const vestId = createEvent.args.id;
      // Revoke the vesting
      await multiVestingWallets.revoke(vestId);
      // Transfer the vest id to addr2
      await expect(multiVestingWallets.connect(addr1).transfer(addr2.address, vestId)).to.be.reverted;
    });
    it("Can't transfer to itself", async () => {
      // Get the current blockchain timestamp
      const startTimestamp = await getTimestampInAFewMoment();
      // Create the vest
      const createTx = await multiVestingWallets.createVest(addr1.address, 100, 0, 100, startTimestamp, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      // Extract the vest id from the create event
      const vestId = createEvent.args.id;
      // Transfer the vest id to addr2
      await expect(multiVestingWallets.connect(addr1).transfer(addr1.address, vestId)).to.be.reverted;
    });
  });

  // Check all the release capabilities
  describe("Vesting revoke", () => {
    it("Can revoke a vesting", async () => {
      // Ensure we can revoke wallet
      const startTime = await getTimestampInAFewMoment();
      const createTx = await multiVestingWallets.createVest(addr1.address, 10, 0, 100, startTime, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      const vestId = createEvent.args.id;
      await multiVestingWallets.revoke(vestId);
      // Got to the end of the duration
      await updatToGivenTimestamp(startTime + 100);
      // Ensure nothing can be unlocked
      await expect(multiVestingWallets.releasableAmount(vestId)).to.be.reverted;
    });
    it("Revoked vesting always refund user", async () => {
      const oldAddr1Balance = await frakToken.balanceOf(addr1.address);
      // Ensure we can revoke wallet
      const startTime = await getTimestampInAFewMoment();
      const createTx = await multiVestingWallets.createVest(addr1.address, 10, 0, 100, startTime, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      const vestId = createEvent.args.id;
      // Got to the end of the duration
      await updatToGivenTimestamp(startTime + 100);
      // Revoke the vesting
      await multiVestingWallets.revoke(vestId);
      // Ensurethe balance was updated
      const newAddr1Balance = await frakToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.be.equal(oldAddr1Balance.add(10));
    });
    it("Can't revoke an un revockable vesting", async () => {
      // Ensure we can revoke wallet
      const startTime = await getTimestampInAFewMoment();
      const createTx = await multiVestingWallets.createVest(addr1.address, 10, 0, 100, startTime, false);
      const createEvent = await extractVestingCreatedEvent(createTx);
      const vestId = createEvent.args.id;
      await expect(multiVestingWallets.revoke(vestId)).to.be.reverted;
    });
    it("Can't revoke a vesting twice", async () => {
      // Ensure we can revoke wallet
      const startTime = await getTimestampInAFewMoment();
      const createTx = await multiVestingWallets.createVest(addr1.address, 10, 0, 100, startTime, true);
      const createEvent = await extractVestingCreatedEvent(createTx);
      const vestId = createEvent.args.id;
      await multiVestingWallets.revoke(vestId);
      await expect(multiVestingWallets.revoke(vestId)).to.be.reverted;
    });
  });

  // Check the roles
  describe("Vesting manager roles", () => {
    testRoles(
      () => multiVestingWallets,
      () => addr1,
      vestingManagerRole,
      [
        async () => {
          await multiVestingWallets
            .connect(addr1)
            .createVest(addr1.address, 100, 10, 10, await getTimestampInAFewMoment(), false);
        },
        async () => {
          await multiVestingWallets
            .connect(addr1)
            .createVestBatch([addr1.address], [100], [10], 10, await getTimestampInAFewMoment(), false);
        },
        async () => {
          await multiVestingWallets
            .connect(addr1)
            .createVest(addr2.address, 100, 10, 10, await getTimestampInAFewMoment(), false);
          await updatToGivenTimestamp(await getTimestampInAFewMoment());
          await multiVestingWallets.connect(addr1).releaseAllFor(addr2.address);
        },
      ],
    );
  });
  describe("Admin roles", () => {
    testRoles(
      () => multiVestingWallets,
      () => addr1,
      adminRole,
      [
        async () => {
          // ensure we can transfer available reserve
          await frakToken.mint(multiVestingWallets.address, 10);
          await multiVestingWallets.connect(addr1).transferAvailableReserve(addr2.address);
        },
        async () => {
          // ensure we can revoke wallet
          await frakToken.mint(multiVestingWallets.address, 10);
          const createTx = await multiVestingWallets.createVest(
            addr1.address,
            10,
            0,
            100,
            await getTimestampInAFewMoment(),
            true,
          );
          const createEvent = await extractVestingCreatedEvent(createTx);
          const vestId = createEvent.args.id;
          await multiVestingWallets.connect(addr1).revoke(vestId);
        },
      ],
    );
  });
  describe("Pauser roles", () => {
    testRoles(
      () => multiVestingWallets,
      () => addr1,
      pauserRole,
      [
        async () => {
          await multiVestingWallets.connect(addr1).pause();
          await multiVestingWallets.connect(addr1).unpause();
        },
      ],
    );
  });
});

export async function extractVestingCreatedEvent(tx: ContractTransaction): Promise<VestingCreatedEvent> {
  const createReceipt = await tx.wait();
  const creationEvent = createReceipt.events?.filter(event => {
    return event.event == "VestingCreated";
  })[0] as VestingCreatedEvent;
  expect(creationEvent).not.to.be.null;
  if (!creationEvent || !creationEvent.args) throw new Error("Unable to find creation event");
  return creationEvent;
}

/*

Base : 
|  MultiVestingWallets   ·  createVest                ·     189 853  ·     192 653  ·         189 975  ·           25  ·       0.02  │
|  MultiVestingWallets   ·  createVestBatch           ·     177 485  ·     451 393  ·         314 439  ·            2  ·       0.03  │
|  MultiVestingWallets                                ·           -  ·           -  ·         3183612  ·       10.6 %  ·       0.27  │


Few revert to error migration (0.633 gained on contract size)

Complete update from revert to error (gained 0.633 + 0.215, almost 1kb)

|  MultiVestingWallets   ·  transfer                  ·          -  ·          -  ·            87588  ·            1  ·       0.02  │
|  MultiVestingWallets   ·  createVest                ·     189 781  ·     192 581  ·         189903  ·           25  ·       0.05  │
|  MultiVestingWallets   ·  createVestBatch           ·     177 412  ·     451 206  ·         314309  ·            2  ·       0.08  │
|  MultiVestingWallets   ·  releaseAll                ·      70 273  ·      87 718  ·          78996  ·            2  ·       0.02  │
|  MultiVestingWallets   ·  releaseAllFor             ·      90 544  ·     108 277  ·          99411  ·            2  ·       0.03  │
|  MultiVestingWallets                                ·          -  ·          -  ·        2 996 887  ·         10 %  ·       0.87  │
|  MultiVestingWallets                                ·          -  ·          -  ·        2 992 831  ·         10 %  ·       1.27  │

Test with variable reorg : 

|  MultiVestingWallets   ·  createVest                ·     189 766  ·     192 566  ·         189888  ·           25  ·       0.08  │
|  MultiVestingWallets   ·  createVestBatch           ·     177 397  ·     451 185  ·         314291  ·            2  ·       0.13  │
|  MultiVestingWallets   ·  release                   ·          -  ·          -  ·          82905  ·            1  ·       0.04  │
|  MultiVestingWallets   ·  releaseAll                ·      70 281  ·      87 726  ·          79004  ·            2  ·       0.03  │
|  MultiVestingWallets   ·  releaseAllFor             ·      90 552  ·     108 293  ·          99423  ·            2  ·       0.04  │



*/
