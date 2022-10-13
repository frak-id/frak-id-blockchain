// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";

import { Contract } from "ethers";

import { SybelToken } from "../types/contracts/tokens/SybelTokenL2.sol/SybelToken";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");
    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log("Sybel token deployed to " + sybelToken.address);
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function deployContract<Type extends Contract>(name: string, args?: unknown[]): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = (await upgrades.deployProxy(contractFactory, args, {
    kind: "uups",
  })) as Type;
  await contract.deployed();
  return contract;
}
