// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";
import * as fs from "fs";

const hre = require("hardhat");

import { Contract, utils } from "ethers";

import { Minter } from "../typechain-types/contracts/minter/Minter";
import * as deployedAddresses from "../addresses.json";
import { FractionCostBadges } from "../typechain-types/contracts/badges/cost/FractionCostBadges";

(async () => {
  try {
    console.log(
      "Deploying all the contract for a simple blockchain intergration"
    );

    // Deploy our new fraction cost badges
    const fractionCostBadges = await deployContract<FractionCostBadges>(
      "FractionCostBadges"
    );
    console.log(
      "Fraction cost badges deployed to " + fractionCostBadges.address
    );

    // Update our minter contract
    const minterFactory = await ethers.getContractFactory("Minter");
    const minter = (await upgrades.upgradeProxy(
      deployedAddresses.minterAddr,
      minterFactory,
      {
        call: {
          fn: "migrateToV3",
          args: [fractionCostBadges.address],
        },
      }
    )) as Minter;
    console.log("Minter syb address updated on " + minter.address);

    console.log("All roles granted with success");

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      fractionCostBadgesAddr: fractionCostBadges.address,
    };
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    // Write another addresses with the name of the current network as backup
    fs.writeFileSync(
      `addresses-${hre.hardhatArguments.network}.json`,
      jsonAddresses
    );
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function deployContract<Type extends Contract>(
  name: string,
  args?: unknown[]
): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = (await upgrades.deployProxy(contractFactory, args, {
    kind: "uups",
  })) as Type;
  await contract.deployed();
  return contract;
}

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

async function findContract<Type extends Contract>(
  name: string,
  address: string
): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}
