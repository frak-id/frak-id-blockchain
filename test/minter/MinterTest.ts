// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { minterRole } from "../../scripts/utils/roles";
import { FrakToken, FraktionTokens, Minter } from "../../types";
import { ContentMintedEvent } from "../../types/contracts/minter/Minter";

describe("Minter", () => {
  let frakToken: FrakToken;
  let fraktionTokens: FraktionTokens;
  let minter: Minter;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    frakToken = await deployContract("FrakToken", [addr2.address]);
    fraktionTokens = await deployContract("FraktionTokens");
    minter = await deployContract("Minter", [frakToken.address, fraktionTokens.address, owner.address]);

    // Grant the minting role to the minter contract
    await fraktionTokens.grantRole(minterRole, minter.address);
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
      await frakToken.mint(addr2.address, cost);

      // Allow the minter contract to perform the frk token transfer
      await frakToken.connect(addr2).approve(minter.address, cost);
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
