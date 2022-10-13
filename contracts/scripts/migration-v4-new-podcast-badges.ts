// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";

import { Minter } from "../types/contracts/minter/Minter";
import * as deployedAddresses from "../addresses.json";
import { Rewarder } from "../types/contracts/reward/Rewarder";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Update our minter contract
    const minterFactory = await ethers.getContractFactory("Minter");
    const minter = (await upgrades.upgradeProxy(deployedAddresses.minterAddr, minterFactory, {
      call: {
        fn: "migrateToV4",
        args: [deployedAddresses.podcastBadgesAddr],
      },
    })) as Minter;
    console.log("Rewarder syb address updated on " + minter.address);

    // Update our rewarder contract
    const rewarderFactory = await ethers.getContractFactory("Rewarder");
    const rewarder = (await upgrades.upgradeProxy(deployedAddresses.rewarderAddr, rewarderFactory, {
      call: {
        fn: "migrateToV4",
        args: [deployedAddresses.podcastBadgesAddr],
      },
    })) as Rewarder;
    console.log("Rewarder syb address updated on " + rewarder.address);
  } catch (e: any) {
    console.log(e.message);
  }
})();
