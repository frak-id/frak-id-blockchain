// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import * as fs from "fs";

import hre from "hardhat";

import { SybelInternalTokens } from "../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../types/contracts/tokens/SybelToken";
import { ListenerBadges } from "../types/contracts/badges/payment/ListenerBadges";
import { PodcastBadges } from "../types/contracts/badges/payment/PodcastBadges";
import { FractionCostBadges } from "../types/contracts/badges/cost/FractionCostBadges";
import { Minter } from "../types/contracts/minter/Minter";
import { Rewarder } from "../types/contracts/reward/Rewarder";
import { FoundationWallet } from "../types/contracts/wallets/FoundationWallet";
import { deployContract } from "./utils/deploy";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Deploy our internal token contract
    const internalToken = await deployContract<SybelInternalTokens>("SybelInternalTokens");
    console.log("Internal tokens deployed to " + internalToken.address);

    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log("Sybel token deployed to " + sybelToken.address);

    // Deploy our sybel foundation wallet contract
    const sybelCorpWallet = (await hre.ethers.getSigners())[0].address;
    const fondationWallet = await deployContract<FoundationWallet>("FoundationWallet", [sybelCorpWallet]);
    console.log(`FoundationWallet deployed to ${fondationWallet.address} with corp wallet ${sybelCorpWallet}`);

    // Deploy our listener and podcast badges contract
    const listenerBadges = await deployContract<ListenerBadges>("ListenerBadges");
    console.log("Listener badges deployed to " + listenerBadges.address);
    const podcastBadges = await deployContract<PodcastBadges>("PodcastBadges");
    console.log("Podcast badges deployed to " + podcastBadges.address);
    const factionCostBadges = await deployContract<FractionCostBadges>("FractionCostBadges");
    console.log("Fraction badges deployed to " + factionCostBadges.address);

    // Deploy our rewarder contract
    const rewarder = await deployContract<Rewarder>("Rewarder", [
      sybelToken.address,
      internalToken.address,
      listenerBadges.address,
      podcastBadges.address,
    ]);
    console.log("Rewarder deployed to " + rewarder.address);

    // Deploy our minter contract
    const minter = await deployContract<Minter>("Minter", [
      sybelToken.address,
      internalToken.address,
      listenerBadges.address,
      podcastBadges.address,
      factionCostBadges.address,
      fondationWallet.address,
    ]);
    console.log("Minter deployed to " + minter.address);

    // Grand all the minting roles
    const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
    await internalToken.grantRole(minterRole, minter.address);
    await internalToken.grantRole(minterRole, rewarder.address);
    await sybelToken.grantRole(minterRole, minter.address);
    await sybelToken.grantRole(minterRole, rewarder.address);

    console.log("All roles granted with success");

    // Build our deplyoed address object
    const addresses = {
      internalTokenAddr: internalToken.address,
      sybelTokenAddr: sybelToken.address,
      listenBadgesAddr: listenerBadges.address,
      podcastBadgesAddr: podcastBadges.address,
      fractionCostBadgesAddr: factionCostBadges.address,
      rewarderAddr: rewarder.address,
      minterAddr: minter.address,
      fondationWalletAddr: fondationWallet.address,
    };
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    // Write another addresses with the name of the current network as backup
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);
  } catch (e: any) {
    console.log(e.message);
  }
})();
