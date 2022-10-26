// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { utils } from "ethers";
import * as fs from "fs";
import { ethers, upgrades } from "hardhat";
import hre from "hardhat";

import * as deployedAddresses from "../addresses.json";
import { Minter } from "../types/contracts/minter/Minter";
import { Rewarder } from "../types/contracts/reward/Rewarder";
import { SybelToken } from "../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { FoundationWallet } from "../types/contracts/wallets/FoundationWallet";
import { deployContract } from "./utils/deploy";

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");
    // Deploy our sybel token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log("Sybel token deployed to " + sybelToken.address);

    // Deploy our sybel foundation wallet contract
    const sybelCorpWallet = (await hre.ethers.getSigners())[0].address;
    const fondationWallet = await deployContract<FoundationWallet>("FoundationWallet", [sybelCorpWallet]);
    console.log(`FoundationWallet deployed to ${fondationWallet.address} with corp wallet ${sybelCorpWallet}`);

    // Update our rewarder contract
    const rewarderFactory = await ethers.getContractFactory("Rewarder");
    const rewarder = (await upgrades.upgradeProxy(deployedAddresses.rewarderAddr, rewarderFactory, {
      call: {
        fn: "migrateToV2",
        args: [sybelToken.address],
      },
    })) as Rewarder;
    await rewarder.deployed();

    console.log("Rewarder syb address updated on " + rewarder.address);

    // Update our minter contract
    const minterFactory = await ethers.getContractFactory("Minter");
    const minter = (await upgrades.upgradeProxy(deployedAddresses.minterAddr, minterFactory, {
      call: {
        fn: "migrateToV2",
        args: [sybelToken.address, fondationWallet.address],
      },
    })) as Minter;
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
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);
  } catch (e: any) {
    console.log(e.message);
  }
})();
