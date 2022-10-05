// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { Contract } from "ethers";

const hre = require("hardhat");

import { SybelToken } from "../typechain-types/contracts/tokens/SybelToken";
import { Minter } from "../typechain-types/contracts/minter/Minter";
import { sybelTokenAddr, minterAddr } from "../addresses.json";

(async () => {
  try {
    console.log(`current network name ${hre.hardhatArguments.network}`);

    // Find our required contracts
    const sybelToken = await findContract<SybelToken>("SybelToken", sybelTokenAddr);

    // Find our required contracts
    const minter = await findContract<Minter>("Minter", minterAddr);
    const fundationWallet = await minter.foundationWallet();
    console.log(`Founded fundation wallet ${fundationWallet}`);

    // Get all the first accounts
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
      const balance = await sybelToken.balanceOf(account.address);
      console.log("The user " + account.address + " have " + balance.toNumber() / 1e6 + "TSE");
    }
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function findContract<Type extends Contract>(name: string, address: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}
