// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { adminRole, minterRole, vestingCreatorRole, vestingManagerRole } from "../../scripts/utils/roles";
import { ContentBadges } from "../../types/contracts/badges/payment/ContentBadges";
import { ListenerBadges } from "../../types/contracts/badges/payment/ListenerBadges";
import { ContentOwnerUpdatedEvent, SybelInternalTokens } from "../../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { ContentPoolMultiContent } from "../../types/contracts/reward/ContentPoolMultiContent";
import { Referral } from "../../types/contracts/reward/Referral";
import { testPauses } from "../utils/test-pauses";
import { testRoles } from "../utils/test-roles";
import { address0, getTimestampInAFewMoment } from "../utils/test-utils";
import { Rewarder } from "../../types/contracts/reward/Rewarder";

const REVOCABLE_GROUP = 1;
const NON_REVOCABLE_GROUP = 2;
const INITIAL_DROP_GROUP = 3;
const groupIds = [REVOCABLE_GROUP, NON_REVOCABLE_GROUP, INITIAL_DROP_GROUP];

const INEXISTANT_GROUP = 100;

const GROUP_CAP = BigNumber.from(10).pow(10);

describe("Rewarder", () => {
  let sybelToken: SybelToken;
  let internalToken: SybelInternalTokens;
  let listenerBadges: ListenerBadges;
  let contentBadges: ContentBadges;
  let referral: Referral;
  let contentPool: ContentPoolMultiContent;
  let rewarder: Rewarder;

  let contentId: BigNumber;

  let _owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let _addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [_owner, addr1, addr2, ..._addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    internalToken = await deployContract("SybelInternalTokens");
    listenerBadges = await deployContract("ListenerBadges");
    contentBadges = await deployContract("ContentBadges");
    referral = await deployContract("Referral", [sybelToken.address]);
    contentPool = await deployContract("ContentPoolMultiContent", [sybelToken.address]);
    rewarder = await deployContract("Rewarder", [
      sybelToken.address,
      internalToken.address,
      listenerBadges.address,
      contentBadges.address,
      contentPool.address,
      referral.address,
    ]);

    // Grand the minter role on the rewarder contract for our nft and frak
    await internalToken.grantRole(minterRole, rewarder.address);
    await sybelToken.grantRole(minterRole, rewarder.address);

    // Setup the callback on the internal tokens for our content pool
    await internalToken.registerNewCallback(contentPool.address);

    // Mint a few contents
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);
    await internalToken.mintNewContent(addr1.address);

    // Perform a mint and we will use this one as content id reference
    const mintEventTxReceipt = await internalToken.mintNewContent(addr1.address);

    // Extract the content id from mint tx
    const mintReceipt = await mintEventTxReceipt.wait();
    const ownerUpdateEvent = mintReceipt.events?.filter(contractEvent => {
      return contractEvent.event == "ContentOwnerUpdated";
    })[0] as ContentOwnerUpdatedEvent;
    if (!ownerUpdateEvent || !ownerUpdateEvent.args) throw new Error("Unable to find creation event");
    contentId = ownerUpdateEvent.args.id;
  });

  describe.only("Base reward", () => {
    it("Reward with free account", async () => {
      // Get all the events emitted
      const owner = await internalToken.ownerOf(contentId);
      console.log(owner);
      // TODO : Should be ko if the podcast isn't existing
      // TODO : We are failing but on the owner address fetching, not goood, should failed before
      await rewarder.payUser(addr1.address, [contentId], [1]);
    });
  });
});

/**
 * Idée transparance boite coté produit :
 *  - Wallet fondation ++ team + vesting -> addresse publique
 *  - Affichage montant locker / deloquable / deloquer dessus (si deloquable > deloquer notion de confiance)
 */
