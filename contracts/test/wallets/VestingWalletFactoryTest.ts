// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "../../scripts/utils/deploy";
import { testPauses } from "../utils/test-pauses";
import { adminRole, minterRole, vestingCreatorRole, vestingManagerRole } from "../../scripts/utils/roles";
import { address0, updateTimestampToEndOfDuration } from "../utils/test-utils";
import { BigNumber, utils } from "ethers";
import { testRoles } from "../utils/test-roles";

const GROUP_INVESTOR_ID = 1;
const GROUP_TEAM_ID = 2;
const GROUP_PRE_SALES_1_ID = 10;
const GROUP_PRE_SALES_2_ID = 11;
const GROUP_PRE_SALES_3_ID = 12;
const GROUP_PRE_SALES_4_ID = 13;
const vestingGroupIds = [
  GROUP_INVESTOR_ID,
  GROUP_TEAM_ID,
  GROUP_PRE_SALES_1_ID,
  GROUP_PRE_SALES_2_ID,
  GROUP_PRE_SALES_3_ID,
  GROUP_PRE_SALES_4_ID,
];

describe("VestingWalletFactory", () => {
  let vestingWalletFactory: VestingWalletFactory;
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
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    multiVestingWallets = await deployContract("MultiVestingWallets", [sybelToken.address]);
    vestingWalletFactory = await deployContract("VestingWalletFactory", [
      sybelToken.address,
      multiVestingWallets.address,
    ]);

    // Grant the vesting manager role to the vesting factory
    await multiVestingWallets.grantRole(vestingManagerRole, vestingWalletFactory.address);

    // Grant the minter role to the vesting wallet factory
    await sybelToken.grantRole(minterRole, vestingWalletFactory.address);

    // Add some initial supply to our vesting group
    await sybelToken.mint(multiVestingWallets.address, 1000);
  });

  describe("Vesting group", () => {
    it("Have all the initial vesting group", async () => {
      // Ensure all the programmed group are present
      for await (const groupId of vestingGroupIds) {
        const fetchedGroup = await vestingWalletFactory.getVestingGroup(groupId);
        expect(fetchedGroup.rewardCap).not.to.equal(0);
        expect(fetchedGroup.supply).to.equal(0);
        expect(fetchedGroup.duration).not.to.equal(0);
      }

      // Ensure group without predicted id arn't present
      const inexistantGroup = await vestingWalletFactory.getVestingGroup(6);
      expect(inexistantGroup.rewardCap).to.equal(0);
      expect(inexistantGroup.duration).to.equal(0);
    });

    it("Can't go past group supply", async () => {
      // Ensure a group supply increase when new vesting created
      const groupId = vestingGroupIds[0];
      const initialVestingGroup = await vestingWalletFactory.getVestingGroup(groupId);

      // Add a new vesting
      // const addTx = await vestingWalletFactory.addVestingWallet(addr1.address, 1, groupId);
      // expect(addTx.hash).to.not.be.null;
      // await updateTimestampToEndOfDuration(addTx);

      // Add a second vesting
      // await expect(vestingWalletFactory.addVestingWallet(addr1.address, initialVestingGroup.rewardCap, groupId)).to
      //   .reverted;
      // expect(addTx.hash).to.not.be.null;
    });

    it("Can't add existing vesting group", async () => {
      // await expect(vestingWalletFactory.addVestingGroup(GROUP_INVESTOR_ID, 10, 10, 10)).to.reverted;
    });

    it("Can't add vesting group with no reward", async () => {
      // await expect(vestingWalletFactory.addVestingGroup(6, 0, 10, 10)).to.reverted;
    });
    it("Can't add vesting group with no duration", async () => {
      // await expect(vestingWalletFactory.addVestingGroup(6, 10, 0, 10)).to.reverted;
    });
    it("Can't add vesting group that exceed the total cap group", async () => {
      //await expect(vestingWalletFactory.addVestingGroup(6, BigNumber.from(10).pow(18).mul(1_500_000_000), 10, 10)).to
      //  .reverted;
    });
  });

  describe("Vesting group", () => {
    it("Can add new vesting, group supplied increased", async () => {
      // Ensure a group supply increase when new vesting created
      const groupId = vestingGroupIds[0];
      const initialVestingGroup = await vestingWalletFactory.getVestingGroup(groupId);

      // Add a new vesting
      // const addTx = await vestingWalletFactory.addVestingWallet(addr1.address, 10, groupId);
      expect(addTx.hash).to.not.be.null;
      await updateTimestampToEndOfDuration(addTx);

      // Ensure the supply increased
      const newVestingGroup = await vestingWalletFactory.getVestingGroup(groupId);
      expect(newVestingGroup.supply).to.equal(initialVestingGroup.supply.add(10));
    });
    it("Can't add new vesting with 0 reward", async () => {
      // await expect(vestingWalletFactory.addVestingWallet(addr1.address, 0, GROUP_INVESTOR_ID)).to.be.reverted;
    });
    it("Can't add new vesting to 0 addr", async () => {
      // await expect(vestingWalletFactory.addVestingWallet(address0, 10, GROUP_INVESTOR_ID)).to.be.reverted;
    });
    it("Can't add new vesting to inexistant group", async () => {
      // await expect(vestingWalletFactory.addVestingWallet(addr1.address, 10, 6)).to.be.reverted;
    });
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => vestingWalletFactory,
      () => addr1,
      [
        async () => {
          // Can't add vesting wallet if paused
          // await vestingWalletFactory.addVestingWallet(addr1.address, 10, GROUP_INVESTOR_ID);
        },
        async () => {
          // await vestingWalletFactory.addVestingGroup(6, 10, 10, 10);
        },
      ],
    );
  });
});

/**
 * Idée transparance boite coté produit :
 *  - Wallet fondation ++ team + vesting -> addresse publique
 *  - Affichage montant locker / deloquable / deloquer dessus (si deloquable > deloquer notion de confiance)
 */
