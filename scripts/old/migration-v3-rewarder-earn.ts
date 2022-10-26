// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import * as fs from "fs";
import { ethers, upgrades } from "hardhat";
import hre from "hardhat";

import * as deployedAddresses from "../addresses.json";
import { PodcastBadges } from "../types/contracts/badges/payment/PodcastBadges";
import { Rewarder } from "../types/contracts/reward/Rewarder";
import { deployContract } from "./utils/deploy";

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
