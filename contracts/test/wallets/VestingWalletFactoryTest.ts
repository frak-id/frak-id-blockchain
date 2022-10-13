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
import { address0, getTimestampInAFewMoment, updateTimestampToEndOfDuration } from "../utils/test-utils";
import { BigNumber, utils } from "ethers";
import { testRoles } from "../utils/test-roles";
import { extractVestingCreatedEvent } from "./MultiVestingWalletsTest";

const REVOCABLE_GROUP = 1;
const NON_REVOCABLE_GROUP = 2;
const INITIAL_DROP_GROUP = 3;
const groupIds = [REVOCABLE_GROUP, NON_REVOCABLE_GROUP, INITIAL_DROP_GROUP];

const INEXISTANT_GROUP = 100;

const GROUP_CAP = BigNumber.from(10).pow(10);

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
    await sybelToken.mint(multiVestingWallets.address, BigNumber.from(10).pow(20));

    // Create an initial vesting groups
    await vestingWalletFactory.addVestingGroup(REVOCABLE_GROUP, GROUP_CAP, 0, 10, true);
    await vestingWalletFactory.addVestingGroup(NON_REVOCABLE_GROUP, GROUP_CAP, 0, 10, false);
    await vestingWalletFactory.addVestingGroup(INITIAL_DROP_GROUP, GROUP_CAP, 100, 10, false);
  });

  describe("Vesting group creation", () => {
    it("Have all the initial vesting group", async () => {
      // Ensure all the programmed group are present
      for await (const groupId of groupIds) {
        const fetchedGroup = await vestingWalletFactory.getVestingGroup(groupId);
        expect(fetchedGroup.rewardCap).not.to.equal(0);
        expect(fetchedGroup.supply).to.equal(0);
        expect(fetchedGroup.duration).not.to.equal(0);
      }

      // Ensure group without predicted id arn't present
      await expect(vestingWalletFactory.getVestingGroup(INEXISTANT_GROUP)).to.be.reverted;
    });
    it("Can't create a group for an existing id", async () => {
      await expect(vestingWalletFactory.addVestingGroup(NON_REVOCABLE_GROUP, GROUP_CAP, 0, 10, false)).to.be.reverted;
    });
    it("Can't create a group with 0 reward", async () => {
      await expect(vestingWalletFactory.addVestingGroup(INEXISTANT_GROUP, 0, 0, 10, false)).to.be.reverted;
    });
    it("Can't create a group with 0 duration", async () => {
      await expect(vestingWalletFactory.addVestingGroup(INEXISTANT_GROUP, 10, 0, 0, false)).to.be.reverted;
    });
    it("Can't create a group with drop per thousand too large", async () => {
      await expect(vestingWalletFactory.addVestingGroup(INEXISTANT_GROUP, 10, 1001, 10, false)).to.be.reverted;
    });
    it("Can't exceed reward cap", async () => {
      await expect(
        vestingWalletFactory.addVestingGroup(
          INEXISTANT_GROUP,
          BigNumber.from(10).pow(18).mul(1_500_000_000),
          1000,
          10,
          false,
        ),
      ).to.be.reverted;
    });
    it("Can transfer founds between two group", async () => {
      const initialGroup = await vestingWalletFactory.getVestingGroup(NON_REVOCABLE_GROUP);
      await vestingWalletFactory.transferGroupReserve(REVOCABLE_GROUP, NON_REVOCABLE_GROUP, 10);
      const afterTransferGroup = await vestingWalletFactory.getVestingGroup(NON_REVOCABLE_GROUP);
      expect(afterTransferGroup.rewardCap).to.equal(initialGroup.rewardCap.add(10));
    });
    it("Can't transfer founds if supply is to low", async () => {
      const initialRevoGroup = await vestingWalletFactory.getVestingGroup(REVOCABLE_GROUP);
      await vestingWalletFactory.addVestingWallet(
        addr1.address,
        initialRevoGroup.rewardCap.sub(50),
        REVOCABLE_GROUP,
        getTimestampInAFewMoment(),
      );
      await expect(vestingWalletFactory.transferGroupReserve(REVOCABLE_GROUP, NON_REVOCABLE_GROUP, 51)).to.be.reverted;
    });
  });

  describe("Vesting wallet creation", () => {
    it("Can add a new beneficiary", async () => {
      // Ensure a group supply increase when new vesting created
      const initialVestingGroup = await vestingWalletFactory.getVestingGroup(REVOCABLE_GROUP);

      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWallet(addr1.address, 10, REVOCABLE_GROUP, getTimestampInAFewMoment()),
      ).not.to.be.reverted;

      // Ensure the group supply has increased
      const updatedVestingGroup = await vestingWalletFactory.getVestingGroup(REVOCABLE_GROUP);
      expect(updatedVestingGroup.supply).to.equal(initialVestingGroup.supply.add(10));
    });
    it("Can't create to unknown group", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWallet(addr1.address, 10, INEXISTANT_GROUP, getTimestampInAFewMoment()),
      ).to.be.reverted;
    });
    it("Can't exceed group reward cap", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWallet(
          addr1.address,
          GROUP_CAP.add(10),
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
    it("Can't exceed total cap", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWallet(
          addr1.address,
          BigNumber.from(10).pow(18).mul(1_500_000_000),
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
    it("Can't create with beneficary 0", async () => {
      // Add a new vesting
      await expect(vestingWalletFactory.addVestingWallet(address0, 10, REVOCABLE_GROUP, getTimestampInAFewMoment())).to
        .be.reverted;
    });
    it("Can't create with 0 reward", async () => {
      // Add a new vesting
      await expect(vestingWalletFactory.addVestingWallet(addr1.address, 0, REVOCABLE_GROUP, getTimestampInAFewMoment()))
        .to.be.reverted;
    });
  });

  describe("Vesting wallet batch creation", () => {
    it("Can add a new beneficiary", async () => {
      // Ensure a group supply increase when new vesting created
      const initialVestingGroup = await vestingWalletFactory.getVestingGroup(REVOCABLE_GROUP);

      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch([addr1.address], [10], REVOCABLE_GROUP, getTimestampInAFewMoment()),
      ).not.to.be.reverted;

      // Add a new vesting with inition drop
      await expect(
        vestingWalletFactory.addVestingWalletBatch(
          [addr1.address],
          [10],
          INITIAL_DROP_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).not.to.be.reverted;

      // Ensure the group supply has increased
      const updatedVestingGroup = await vestingWalletFactory.getVestingGroup(REVOCABLE_GROUP);
      expect(updatedVestingGroup.supply).to.equal(initialVestingGroup.supply.add(10));
    });
    it("Can't create with empty array size", async () => {
      // Add a new vesting
      await expect(vestingWalletFactory.addVestingWalletBatch([], [], REVOCABLE_GROUP, getTimestampInAFewMoment())).to
        .be.reverted;
    });
    it("Can't create with different array size", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch(
          [addr1.address],
          [10, 10],
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
    it("Can't create to unknown group", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch([addr1.address], [10], INEXISTANT_GROUP, getTimestampInAFewMoment()),
      ).to.be.reverted;
    });
    it("Can't exceed group reward cap", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch(
          [addr1.address, addr2.address],
          [GROUP_CAP, 1],
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
    it("Can't create with beneficary 0", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch(
          [addr1.address, address0],
          [10, 10],
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
    it("Can't create with 0 reward", async () => {
      // Add a new vesting
      await expect(
        vestingWalletFactory.addVestingWalletBatch(
          [addr1.address, addr2.address],
          [10, 0],
          REVOCABLE_GROUP,
          getTimestampInAFewMoment(),
        ),
      ).to.be.reverted;
    });
  });

  // Test the roles
  describe("Vesting creator roles", () => {
    testRoles(
      () => vestingWalletFactory,
      () => addr1,
      vestingCreatorRole,
      [
        async () => {
          // Can't add vesting wallet if paused
          await vestingWalletFactory
            .connect(addr1)
            .addVestingWallet(addr1.address, 10, INITIAL_DROP_GROUP, getTimestampInAFewMoment());
        },
        async () => {
          // Can't add vesting wallet if paused
          await vestingWalletFactory
            .connect(addr1)
            .addVestingWalletBatch([addr1.address], [10], REVOCABLE_GROUP, getTimestampInAFewMoment());
        },
      ],
    );
  });
  describe("Admin roles", () => {
    testRoles(
      () => vestingWalletFactory,
      () => addr1,
      adminRole,
      [
        async () => {
          // Can't add vesting groyp if paused
          await vestingWalletFactory.connect(addr1).addVestingGroup(INEXISTANT_GROUP, 10, 10, 10, false);
        },
      ],
    );
  });

  // Check the pausable capabilities
  describe("Pauses", () => {
    testPauses(
      () => vestingWalletFactory,
      () => addr1,
      [
        async () => {
          // Can't add vesting wallet if paused
          await vestingWalletFactory.addVestingWallet(addr1.address, 10, REVOCABLE_GROUP, getTimestampInAFewMoment());
        },
        async () => {
          // Can't add vesting wallet if paused
          await vestingWalletFactory.addVestingWalletBatch(
            [addr1.address],
            [10],
            REVOCABLE_GROUP,
            getTimestampInAFewMoment(),
          );
        },
        async () => {
          // Can't add vesting groyp if paused
          await vestingWalletFactory.addVestingGroup(INEXISTANT_GROUP, 10, 10, 10, false);
        },
        async () => {
          // Can't transfer if paused
          await vestingWalletFactory.transferGroupReserve(REVOCABLE_GROUP, NON_REVOCABLE_GROUP, 10);
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
