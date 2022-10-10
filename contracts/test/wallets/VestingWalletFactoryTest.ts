// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { SybelToken } from "../../types/contracts/tokens/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployContract } from "../../scripts/utils/deploy";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { minterRole, vestingCreatorRole, vestingManagerRole } from "../../scripts/utils/roles";

const GROUP_INVESTOR_ID = 1;
const GROUP_TEAM_ID = 2;
const GROUP_PRE_SALES_1_ID = 10;
const GROUP_PRE_SALES_2_ID = 11;
const GROUP_PRE_SALES_3_ID = 12;
const GROUP_PRE_SALES_4_ID = 13;

describe.only("VestingWalletFactory", () => {
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
    sybelToken = await deployContract("SybelToken");
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
      const groupIds = [
        GROUP_INVESTOR_ID,
        GROUP_TEAM_ID,
        GROUP_PRE_SALES_1_ID,
        GROUP_PRE_SALES_2_ID,
        GROUP_PRE_SALES_3_ID,
        GROUP_PRE_SALES_4_ID,
      ];
      for await (const groupId of groupIds) {
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
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => vestingWalletFactory,
      () => addr1,
      [
        async () => {
          // Can't add vesting wallet if paused
          await vestingWalletFactory.addVestingWallet(addr1.address, 10, GROUP_INVESTOR_ID);
        },
      ],
    );
  });
});
