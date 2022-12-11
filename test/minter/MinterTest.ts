// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { minterRole } from "../../scripts/utils/roles";
import { Minter, SybelInternalTokens } from "../../types";
import { ContentMintedEvent } from "../../types/contracts/minter/Minter";
import { ContentOwnerUpdatedEvent } from "../../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";

describe("Minter", () => {
  let sybelToken: SybelToken;
  let internalToken: SybelInternalTokens;
  let minter: Minter;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our sybel contract
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    sybelToken = await deployContract("SybelToken", [addr2.address]);
    internalToken = await deployContract("SybelInternalTokens");
    minter = await deployContract("Minter", [sybelToken.address, internalToken.address, owner.address]);

    // Grant the minting role to the minter contract
    await internalToken.grantRole(minterRole, minter.address);
  });

  describe("Base mint", () => {
    it("Single mint", async () => {
      await minter.addContent(addr1.address, 10, 10, 10, 4);
    });
    it("Mint a few contents", async () => {
      for (const addr of addrs) {
        // Update the share, and add some reward for this content
        await minter.addContent(addr.address, 10, 10, 10, 4);
      }
    });
    it("Mint a few contents at limit", async () => {
      for (const addr of addrs) {
        // Update the share, and add some reward for this content
        await minter.addContent(addr.address, 10, 10, 10, 5);
      }
    });
  });

  describe("User buy fraktion", () => {
    it("Single fraktion buy", async () => {
      // Mint a content and get it's id
      const mintEventTxReceipt = await minter.addContent(addr1.address, 10, 10, 10, 5);
      const mintReceipt = await mintEventTxReceipt.wait();
      const ownerUpdateEvent = mintReceipt.events?.filter(contractEvent => {
        return contractEvent.event == "ContentMinted";
      })[0] as ContentMintedEvent;
      if (!ownerUpdateEvent || !ownerUpdateEvent.args) throw new Error("Unable to find creation event");
      const mintedTokenId = ownerUpdateEvent.args.baseId;

      // Build the fraktion id
      const fraktionId = buildFractionId(mintedTokenId, 4);

      // Get the cost of the given fraktion
      const cost = await minter.getCostBadge(fraktionId);
      console.log(`Fraktion cost ${cost}`);

      // Mint the token required for our user
      await sybelToken.mint(addr2.address, cost);

      // Allow the minter contract to perform the frk token transfer
      await sybelToken.connect(addr2).approve(minter.address, cost);
      console.log("Transfer approved");

      // Perform the transfer
      await minter.mintFractionForUser(fraktionId, addr2.address, 1);
      console.log("Fraktion minted");
    });
  });
});

export function buildFractionId(contentId: BigNumberish, tokenType: number): BigNumber {
  return BigNumber.from(contentId).shl(4).or(BigNumber.from(tokenType));
}

/*
Base : 
|  Minter    ·  addContent  ·     320 553  ·     320 565  ·         320 564  ·           18  ·       0.03  │
|  Minter                   ·          -  ·          -  ·         2 332 636  ·        7.8 %  ·       0.22  │

Change revert to error : 
|  Minter    ·  addContent  ·     320 571  ·     320 583  ·         320 582  ·           18  ·       0.02  │
|  Minter                   ·          -  ·          -  ·         2 232 095  ·        7.4 %  ·       0.13  │
*/
