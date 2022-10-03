// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { ethers, upgrades } from "hardhat";
import * as fs from "fs";

const hre = require("hardhat");

import { Contract, utils } from "ethers";

import { SybelInternalTokens } from "../typechain-types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../typechain-types/contracts/tokens/SybelToken";
import { ListenerBadges } from "../typechain-types/contracts/badges/payment/ListenerBadges";
import { PodcastBadges } from "../typechain-types/contracts/badges/payment/PodcastBadges";
import { FractionCostBadges } from "../typechain-types/contracts/badges/cost/FractionCostBadges";
import { Minter } from "../typechain-types/contracts/minter/Minter";
import { Rewarder } from "../typechain-types/contracts/reward/Rewarder";
import { FoundationWallet } from "../typechain-types/contracts/wallets/FoundationWallet";

(async () => {
  try {
    console.log(
      "Deploying all the contract for a simple blockchain intergration"
    );
    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log("Sybel token deployed to " + sybelToken.address);
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

// Immutable data object
class DeployedAddress {
  constructor(
    readonly internalTokenAddr: String,
    readonly sybelTokenAddr: String,
    readonly listenBadgesAddr: String,
    readonly podcastBadgesAddr: String,
    readonly fractionCostBadgesAddr: String,
    readonly rewarderAddr: String,
    readonly minterAddr: String
  ) {}

  toJson(): string {
    return JSON.stringify(this);
  }
}
