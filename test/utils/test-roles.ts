import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";

import { SybelAccessControlUpgradeable } from "../../types/contracts/utils/SybelAccessControlUpgradeable";

// Check the Roles managment
export const testRoles = (
  contractAccessor: () => SybelAccessControlUpgradeable,
  addr1Accessor: () => SignerWithAddress,
  role: string,
  roleRequiredFunctions: (() => Promise<void>)[],
) => {
  let contract: SybelAccessControlUpgradeable;
  let addr1: SignerWithAddress;
  beforeEach(() => {
    contract = contractAccessor();
    addr1 = addr1Accessor();
  });

  it("Owner can grant new role", async () => {
    // Check if the addr2 hasn't the minting roles
    let isAddr1WithRole = await contract.hasRole(role, addr1.address);

    expect(isAddr1WithRole).to.equal(false);

    // Grant the role and check he got it
    await contract.grantRole(role, addr1.address);
    isAddr1WithRole = await contract.hasRole(role, addr1.address);

    expect(isAddr1WithRole).to.equal(true);

    // Then try to perform a mint and ensure it don't fail
    for await (const roleRequiredFunction of roleRequiredFunctions) {
      await expect(roleRequiredFunction()).not.to.be.reverted;
    }
  });
  it("Owner can revoke role", async () => {
    // Grant the role and check he got it
    await contract.grantRole(role, addr1.address);
    let isAddr1WithRole = await contract.hasRole(role, addr1.address);

    expect(isAddr1WithRole).to.equal(true);

    // Revoke the role and check the user havn't it anymore
    await contract.revokeRole(role, addr1.address);
    isAddr1WithRole = await contract.hasRole(role, addr1.address);

    // Then try to perform the role required functions
    for await (const roleRequiredFunction of roleRequiredFunctions) {
      await expect(roleRequiredFunction()).to.be.reverted;
    }
  });
  it("User can renounce role", async () => {
    // Grant the role and check he got it
    await contract.grantRole(role, addr1.address);
    let isAddr1WithRole = await contract.hasRole(role, addr1.address);
    expect(isAddr1WithRole).to.equal(true);

    // Renounce the role and check the user havn't it anymore
    await contract.connect(addr1).renounceRole(role, addr1.address);
    isAddr1WithRole = await contract.hasRole(role, addr1.address);

    // Then try to perform the role required functions
    for await (const roleRequiredFunction of roleRequiredFunctions) {
      await expect(roleRequiredFunction()).to.be.reverted;
    }
  });
};
