// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { SybelToken } from "../../types/contracts/tokens/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "../../scripts/utils/deploy";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { pauserRole, minterRole, adminRole, vestingCreatorRole, vestingManagerRole } from "../../scripts/utils/roles";
import { getTimestampInAFewMoment, updateTimestampToEndOfDuration, updatToGivenTimestamp } from "../utils/test-utils";

describe.only("MultipleVestingWallets", () => {
  let multiVestingWallets: MultiVestingWallets;
  let sybelToken: SybelToken;

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy our sybel token and vesting wallets
    sybelToken = await deployContract("SybelToken");
    multiVestingWallets = await deployContract("MultiVestingWallets", [sybelToken.address]);

    // Grant the minter role to the vesting wallets
    await sybelToken.grantRole(minterRole, multiVestingWallets.address);

    // Add some initial supply to our vesting group
    await sybelToken.mint(multiVestingWallets.address, 10000000);
  });

  describe("Faking ERC20", () => {
    it("Have all the properties for an erc20 token", async () => {
      // Get the name, symbol and decimals
      const name = await multiVestingWallets.name();
      const symbol = await multiVestingWallets.symbol();
      const decimals = await multiVestingWallets.decimals();

      expect(name).not.to.be.null;
      expect(symbol).to.equal("vSYBL");
      expect(decimals).to.equal(await sybelToken.decimals());
    });
  });

  // Checl all the investors capabilities
  describe("Investors", () => {
    it("Can add a new vesting wallet, user release itself his founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);
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
      let newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(50));
      // Wait for end of the cliff, and ensure the remaining amount can be unlocked
      await updatToGivenTimestamp(startTimestamp + 100);
      await multiVestingWallets.connect(addr1).releaseAll();
      newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(100));
    });
    it("Can add multiple vesting wallets, owner release user founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);
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
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(200));
    });
    it("Can't create if past date", async () => {
      await multiVestingWallets.createVest(addr1.address, 100, 10, 10, (await getTimestampInAFewMoment()) - 5, false);
      await expect(multiVestingWallets.releaseAllFor(addr1.address)).to.be.reverted;
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
          [100, 100, 100],
          [10, 10, 10],
          0,
          await getTimestampInAFewMoment(),
          false,
        ),
      ).to.be.reverted;
    });
    it("Can't add walletthat exceed the balance of the adress", async () => {
      // Try to create the vest
      await expect(
        multiVestingWallets.createVest(addr1.address, 1000000, 1000, 10, await getTimestampInAFewMoment(), false),
      ).to.be.reverted;
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
            .createVest(addr1.address, 10, 10, 10, await getTimestampInAFewMoment(), false);
        },
        async () => {
          await multiVestingWallets
            .connect(addr1)
            .createVestBatch([addr1.address], [10], [10], 10, await getTimestampInAFewMoment(), false);
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
