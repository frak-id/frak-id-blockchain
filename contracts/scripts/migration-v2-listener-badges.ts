// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";
import * as fs from "fs";

const hre = require("hardhat");

import { Contract, utils } from "ethers";

import { SybelToken } from "../typechain-types/contracts/tokens/SybelToken";
import { FoundationWallet } from "../typechain-types/contracts/wallets/FoundationWallet";
import { Minter } from "../typechain-types/contracts/minter/Minter";
import { Rewarder } from "../typechain-types/contracts/reward/Rewarder";
import * as deployedAddresses from "../addresses.json";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Update our rewarder contract
    const listenerFactory = await ethers.getContractFactory("ListenerBadges");
    const listener = (await upgrades.upgradeProxy(deployedAddresses.listenBadgesAddr, listenerFactory)) as Rewarder;
    await listener.deployed();

    console.log("Listener badges  updated on " + listener.address);
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

async function updateContract<Type extends Contract>(name: string, proxyAddress: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = (await upgrades.upgradeProxy(proxyAddress, contractFactory)) as Type;
  await contract.deployed();
  return contract;
}
