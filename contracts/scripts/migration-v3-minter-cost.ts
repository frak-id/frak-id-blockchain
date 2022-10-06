// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";
import * as fs from "fs";

import hre from "hardhat";

import { Minter } from "../types/contracts/minter/Minter";
import * as deployedAddresses from "../addresses.json";
import { FractionCostBadges } from "../types/contracts/badges/cost/FractionCostBadges";
import { deployContract } from "./utils/deploy";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Deploy our new fraction cost badges
    const fractionCostBadges = await deployContract<FractionCostBadges>("FractionCostBadges");
    console.log("Fraction cost badges deployed to " + fractionCostBadges.address);

    // Update our minter contract
    const minterFactory = await ethers.getContractFactory("Minter");
    const minter = (await upgrades.upgradeProxy(deployedAddresses.minterAddr, minterFactory, {
      call: {
        fn: "migrateToV3",
        args: [fractionCostBadges.address],
      },
    })) as Minter;
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
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);
  } catch (e: any) {
    console.log(e.message);
  }
})();
