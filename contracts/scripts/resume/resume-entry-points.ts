// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { Contract } from "ethers";

import { rewarderAddr, minterAddr } from "../../addresses.json";
import { Rewarder } from "../../typechain-types/contracts/reward/Rewarder";
import { Minter } from "../../typechain-types/contracts/minter/Minter";

(async () => {
  try {
    console.log("Resume all the entry points contract");

    // Find the contract we want to resume
    const rewarder = await findContract<Rewarder>("Rewarder", rewarderAddr);
    const minter = await findContract<Minter>("Minter", minterAddr);

    // Resume each one of them
    await rewarder.unpause();
    await minter.unpause();
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function findContract<Type extends Contract>(name: string, address: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}
