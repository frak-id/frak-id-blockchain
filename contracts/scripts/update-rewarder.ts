// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";

import { Contract } from "ethers";

import { Rewarder } from "../typechain-types/contracts/reward/Rewarder";

import { rewarderAddr } from "../addresses.json";

(async () => {
  try {
    console.log("Updating the rewarder contract");

    // Deploy our rewarder contract
    const rewarder = await updateContract<Rewarder>("Rewarder", rewarderAddr);
    console.log("Rewarder updated to " + rewarder.address);
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function updateContract<Type extends Contract>(
  name: string,
  proxyAddress: string
): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = (await upgrades.upgradeProxy(
    proxyAddress,
    contractFactory
  )) as Type;
  await contract.deployed();
  return contract;
}
