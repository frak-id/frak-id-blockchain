// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../../scripts/utils/deploy";
import { BUYABLE_TOKEN_TYPES, buildFractionId } from "../../scripts/utils/mathUtils";
import { rewarderRole, tokenContractRole } from "../../scripts/utils/roles";
import { ContentPool, FrakToken } from "../../types";
import { address0 } from "../utils/test-utils";

// Testing our content pool contract
describe("ContentPool", () => {
  let frakToken: FrakToken;
  let contentPool: ContentPool;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  // Deploy our frak contract
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy all the necessary contract for our rewarder
    frakToken = await deployContract("FrakToken", [addr2.address]);
    contentPool = await deployContract("ContentPool", [frakToken.address]);

    // Grant the rewarder role to the referral contract
    await contentPool.grantRole(rewarderRole, owner.address);
    await contentPool.grantRole(tokenContractRole, owner.address);

    // Mint some token to the pool
    await frakToken.mint(contentPool.address, BigNumber.from(10).pow(24));
  });

  describe("Update pool state and add reward", () => {
    it("Initial test", async () => {
      await buildLotOfStates();

      for (let addrIndex = 0; addrIndex < addrs.length; addrIndex++) {
        const addr = addrs[addrIndex];

        // Ask to withdraw the content
        await contentPool["withdrawFounds(address)"](addr.address);
      }
    });
  });

  /**
   * Build a large referee chain with all the known address
   */
  const buildLotOfStates = async () => {
    // Ensure when no referrer are in the chain, no reward are given
    for (let index = 0; index < 5; index++) {
      for (const addr of addrs) {
        for (const tokenType of BUYABLE_TOKEN_TYPES) {
          // Update the share, and add some reward for this content
          await contentPool.onFraktionsTransferred(address0, addr.address, [buildFractionId(index, tokenType)], [5]);
          await contentPool.addReward(index, BigNumber.from(10).pow(18).mul(10));
        }
      }
    }
  };
});
