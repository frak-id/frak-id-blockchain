// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "ethers";
import { verifyTypedData } from "ethers/lib/utils";
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
    fraktionTokens = await deployContract("FraktionTokens", ["url"]);
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

      // Mint the token required for our user
      await frakToken.mint(addr2.address, cost);

      // Create the permit hash
      const userNonce = await frakToken.getNonce(addr2.address);
      const deadline = Math.floor(Date.now() / 1000 + 60 * 10);

      const domainData = {
        name: "Frak",
        version: "1",
        chainId: 31337,
        verifyingContract: frakToken.address,
      };
      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };
      const value = {
        owner: addr2.address,
        spender: minter.address,
        value: cost,
        nonce: userNonce,
        deadline: deadline,
      };

      const signature = await addr2._signTypedData(domainData, types, value);

      // Extract signature part
      const withoutHexPrefix = signature.substring(2);
      const r = withoutHexPrefix.substring(0, 64);
      const s = withoutHexPrefix.substring(64, 128);
      const v = withoutHexPrefix.substring(128, 130);

      // Perform the transfer
      await minter.mintFraktionForUser(fraktionId, addr2.address, deadline, `0x${v}`, `0x${r}`, `0x${s}`);
      console.log("Fraktion minted");
    });
  });
});

export function buildFractionId(contentId: BigNumberish, tokenType: number): BigNumber {
  return BigNumber.from(contentId).shl(4).or(BigNumber.from(tokenType));
}
