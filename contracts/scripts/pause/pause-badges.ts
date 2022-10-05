// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers } from "hardhat";

import { Contract } from "ethers";

import { listenBadgesAddr, podcastBadgesAddr, fractionCostBadgesAddr } from "../../addresses.json";
import { ListenerBadges } from "../../typechain-types/contracts/badges/payment/ListenerBadges";
import { PodcastBadges } from "../../typechain-types/contracts/badges/payment/PodcastBadges";
import { FractionCostBadges } from "../../typechain-types/contracts/badges/cost/FractionCostBadges";

(async () => {
  try {
    console.log("Pausing all the badges contract");

    // Find the contract we want to pause
    const listenerBadges = await findContract<ListenerBadges>("ListenerBadges", listenBadgesAddr);
    const podcastBadges = await findContract<PodcastBadges>("PodcastBadges", podcastBadgesAddr);
    const fractionCostBadges = await findContract<FractionCostBadges>("FractionCostBadges", fractionCostBadgesAddr);

    // Pause each one of them
    await listenerBadges.pause();
    await podcastBadges.pause();
    await fractionCostBadges.pause();
  } catch (e: any) {
    console.log(e.message);
  }
})();

async function findContract<Type extends Contract>(name: string, address: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}
