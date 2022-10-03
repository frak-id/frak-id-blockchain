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
    console.log(
      "Deploying all the contract for a simple blockchain intergration"
    );
    // Deploy our sybel token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log("Sybel token deployed to " + sybelToken.address);

    // Deploy our sybel foundation wallet contract
    const sybelCorpWallet = (await hre.ethers.getSigners())[0].address;
    const fondationWallet = await deployContract<FoundationWallet>(
      "FoundationWallet",
      [sybelCorpWallet]
    );
    console.log(
      `FoundationWallet deployed to ${fondationWallet.address} with corp wallet ${sybelCorpWallet}`
    );

    // Update our rewarder contract
    const rewarderFactory = await ethers.getContractFactory("Rewarder");
    const rewarder = (await upgrades.upgradeProxy(
      deployedAddresses.rewarderAddr,
      rewarderFactory,
      {
        call: {
          fn: "migrateToV2",
          args: [sybelToken.address],
        },
      }
    )) as Rewarder;
    await rewarder.deployed();

    console.log("Rewarder syb address updated on " + rewarder.address);

    // Update our minter contract
    const minterFactory = await ethers.getContractFactory("Minter");
    const minter = (await upgrades.upgradeProxy(
      deployedAddresses.minterAddr,
      minterFactory,
      {
        call: {
          fn: "migrateToV2",
          args: [sybelToken.address, fondationWallet.address],
        },
      }
    )) as Minter;
    console.log("Minter syb address updated on " + minter.address);

    // Grand all the minting roles
    const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
    await sybelToken.grantRole(minterRole, minter.address);
    await sybelToken.grantRole(minterRole, rewarder.address);

    console.log("All roles granted with success");

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      sybelTokenAddr: sybelToken.address,
      fondationWalletAddr: fondationWallet.address,
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
