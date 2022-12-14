import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";

import { FrakAccessControlUpgradeable } from "../../types";

// Check the Roles managment
export const testPauses = (
  contractAccessor: () => FrakAccessControlUpgradeable,
  addr1Accessor: () => SignerWithAddress,
  unpausedRequiredFunctions: (() => Promise<void>)[],
) => {
  let contract: FrakAccessControlUpgradeable;
  let addr1: SignerWithAddress;
  beforeEach(async () => {
    contract = contractAccessor();
    addr1 = addr1Accessor();

    // Pause the contract
    await contract.pause();
  });

  it("Method fail when paused", async () => {
    for await (const unpauseRequiredFunction of unpausedRequiredFunctions) {
      await expect(unpauseRequiredFunction()).to.be.reverted;
    }
  });

  it("Owner can unpause ", async () => {
    await contract.unpause();
    for await (const unpauseRequiredFunction of unpausedRequiredFunctions) {
      await expect(unpauseRequiredFunction()).not.to.be.reverted;
    }
  });

  it("User can't unpause ", async () => {
    await expect(contract.connect(addr1).unpause()).to.be.reverted;
  });
};
