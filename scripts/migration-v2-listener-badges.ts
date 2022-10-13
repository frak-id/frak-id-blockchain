// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";

import { Rewarder } from "../types/contracts/reward/Rewarder";
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
