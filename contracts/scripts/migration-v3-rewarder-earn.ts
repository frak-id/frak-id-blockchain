// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";
import * as fs from "fs";

const hre = require("hardhat");

import { Contract, utils } from "ethers";

import { Minter } from "../typechain-types/contracts/minter/Minter";
import * as deployedAddresses from "../addresses.json";
import { FractionCostBadges } from "../typechain-types/contracts/badges/cost/FractionCostBadges";
import { PodcastBadges } from "../typechain-types/contracts/badges/payment/PodcastBadges";
import { Rewarder } from "../typechain-types/contracts/reward/Rewarder";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Deploy our new podcast badges
    const podcastBadges = await deployContract<PodcastBadges>("PodcastBadges");
    console.log("Podcast badges deployed to " + podcastBadges.address);

    // Update our rewarder contract
    const rewarderFactory = await ethers.getContractFactory("Rewarder");
    const rewarder = (await upgrades.upgradeProxy(deployedAddresses.rewarderAddr, rewarderFactory, {
      call: {
        fn: "migrateToV3",
      },
    })) as Rewarder;
    console.log("Rewarder syb address updated on " + rewarder.address);

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      podcastBadges: podcastBadges.address,
    };
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    // Write another addresses with the name of the current network as backup
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);
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

async function findContract<Type extends Contract>(name: string, address: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}
