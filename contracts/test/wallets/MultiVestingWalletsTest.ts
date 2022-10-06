// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { BigNumber, BigNumberish, ContractTransaction, utils } from "ethers";

import { SybelToken } from "../../types/contracts/tokens/SybelToken";
import { VestingWallets } from "../../types/contracts/wallets/VestingWallets";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
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

describe("MultipleVestingWallets", () => {
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
    const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
    await sybelToken.grantRole(minterRole, multiVestingWallets.address);

    // Add some initial supply to our vesting group
    await sybelToken.mint(multiVestingWallets.address, 1000);
  });

  describe("Faking ERC20", () => {
    it("Have all the properties for an erc20 token", async () => {
      // Get the name, symbol and decimals
      const name = await multiVestingWallets.name();
      const symbol = await multiVestingWallets.symbol();
      const decimals = await multiVestingWallets.decimals();

      expect(name).not.to.be.null;
      expect(symbol).to.equal("mvSYBL");
      expect(decimals).to.equal(await sybelToken.decimals());
    });
  });

  // Checl all the investors capabilities
  describe("Investors", () => {
    it("Can add a new vesting wallet, user release itself his founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);
      // Create the vest
      await multiVestingWallets.createVest(addr1.address, 100, 10, 10);
      // Start the vesting phase
      const beginTx = await multiVestingWallets.beginNow();
      // Check the number of vesting the beneficiary add
      const balanceOfVest = await multiVestingWallets.balanceOf(addr1.address);
      expect(balanceOfVest).to.equal(100);
      // Check the number of vesting the beneficiary add
      const numberOfVest = await multiVestingWallets.ownedCount(addr1.address);
      expect(numberOfVest).to.equal(1);
      // Go to the end of the delay and unlock duration
      await updateTimestampToEndOfDuration(beginTx, 2000);
      // Ensure the user can release his amount, and ensure his balance was updated
      await multiVestingWallets.connect(addr1).releaseAll();
      // Get the original balance of an investor
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(100));
    });
    it("Can add multiple vesting wallets, owner release user founds, and balance update", async () => {
      // Get the original balance of an investor
      const oldAddr1Balance = await sybelToken.balanceOf(addr1.address);
      // Create the vest
      await multiVestingWallets.createVestBatch([addr1.address, addr2.address, addr1.address], [100, 100, 100], 10, 10);
      // Start the vesting phase
      const beginTx = await multiVestingWallets.beginNow();
      // Check the number of vesting the beneficiary add
      const balanceOfVest = await multiVestingWallets.balanceOf(addr1.address);
      expect(balanceOfVest).to.equal(200);
      // Check the number of vesting the beneficiary add
      const numberOfVestAddr1 = await multiVestingWallets.ownedCount(addr1.address);
      expect(numberOfVestAddr1).to.equal(2);
      // Check the number of vesting the beneficiary add
      const numberOfVestAddr2 = await multiVestingWallets.ownedCount(addr2.address);
      expect(numberOfVestAddr2).to.equal(1);
      // Go to the end of the delay and unlock duration
      await updateTimestampToEndOfDuration(beginTx, 2000);
      // Ensure the user can release his amount, and ensure his balance was updated
      await multiVestingWallets.releaseAllFor(addr1.address);
      // Get the original balance of an investor
      const newAddr1Balance = await sybelToken.balanceOf(addr1.address);
      expect(newAddr1Balance).to.equal(oldAddr1Balance.add(200));
    });
    it("Can't add single vesting wallet after begin", async () => {
      // Start the vesting phase
      await multiVestingWallets.beginNow();
      // Try to create the vest
      await expect(multiVestingWallets.createVest(addr1.address, 100, 10, 10)).to.be.reverted;
    });
    it("Can't unlock if not started", async () => {
      await multiVestingWallets.createVest(addr1.address, 100, 10, 10);
      // Try to create the vest
      await expect(multiVestingWallets.releaseAllFor(addr1.address)).to.be.reverted;
    });
    it("Can't add multiple vesting wallet after begin", async () => {
      // Start the vesting phase
      await multiVestingWallets.beginNow();
      // Try to create the vest
      await expect(multiVestingWallets.createVestBatch([addr1.address], [100], 10, 10)).to.be.reverted;
    });
    it("Can't add single vesting wallet with 0 delay and duration", async () => {
      // Try to create the vest
      await expect(multiVestingWallets.createVest(addr1.address, 100, 0, 0)).to.be.reverted;
    });
    it("Can't add multiple vesting wallet with 0 delay and duration", async () => {
      // Start the vesting phase
      await multiVestingWallets.beginNow();
      // Try to create the vest
      await expect(multiVestingWallets.createVestBatch([addr1.address], [100], 0, 0)).to.be.reverted;
    });
    it("Can't add multiple vesting wallet with different sizes", async () => {
      // Start the vesting phase
      await multiVestingWallets.beginNow();
      // Try to create the vest
      await expect(multiVestingWallets.createVestBatch([addr1.address], [100, 100, 100], 0, 0)).to.be.reverted;
    });
    it("Can't add walletthat exceed the balance of the adress", async () => {
      // Try to create the vest
      await expect(multiVestingWallets.createVest(addr1.address, 1000000, 10, 10)).to.be.reverted;
    });
  });

  // Check the roles
  /*describe("Admin roles", () => {
    testRoles(
      () => multiVestingWallets,
      () => addr1,
      adminRole,
      [
        async () => {
          await vestingWallets.connect(addr1).addVestingGroup(13, 10, 10, 10);
        },
      ],
    );
  });*/
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

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => multiVestingWallets,
      () => addr1,
      [
        async () => {
          // Can't create vest and release
          await multiVestingWallets.createVest(addr1.address, 100, 10, 10);
          await multiVestingWallets.createVestBatch([addr1.address, addr2.address], [100, 100], 10, 10);

          const beginTx = await multiVestingWallets.beginNow();

          await updateTimestampToEndOfDuration(beginTx, 20);

          await multiVestingWallets.releaseAllFor(addr1.address);
          await multiVestingWallets.connect(addr2).releaseAll();
        },
      ],
    );
  });

  async function updateTimestampToEndOfDuration(tx: ContractTransaction, duration: BigNumberish) {
    // Wait for the tx to be mined
    await tx.wait();
    const txMined = await ethers.provider.getTransaction(tx.hash);
    const blockTimestamp = (await ethers.provider.getBlock(txMined.blockHash!)).timestamp;
    // Get the investor group duration
    const newTimestamp = BigNumber.from(blockTimestamp).add(duration).toNumber();
    // Increase the blockchain timestamp
    await ethers.provider.send("evm_mine", [newTimestamp]);
  }
});
