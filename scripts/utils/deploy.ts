import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";

/**
 * Deploy a new contract
 */
export async function deployContract<Type extends Contract>(name: string, args?: unknown[]): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = (await upgrades.deployProxy(contractFactory, args, {
    kind: "uups",
  })) as Type;
  await contract.deployed();
  return contract;
}
