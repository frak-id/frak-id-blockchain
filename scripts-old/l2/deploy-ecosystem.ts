import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { ContentPool, FraktionTokens, Minter, ReferralPool, Rewarder } from "../../types";
import { deployContract } from "../utils/deploy";
import { minterRole, rewarderRole, tokenContractRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the eco system contracts");

    // Get the right child predicate depending on the env
    const networkName = hre.hardhatArguments.network ?? "local";
    let erc20TokenAddr: string;
    let foundationWallet: string;
    let metadataUrl: string;
    if (networkName == "mumbai") {
      erc20TokenAddr = deployedAddresses.mumbai.frakToken;
      foundationWallet = "0x8Cb488e0E16e49F064e210969EE1c771a55BcD04";
      metadataUrl = "https://metadata-dev.frak.id/json/{id.json}";
    } else if (networkName == "polygon") {
      erc20TokenAddr = deployedAddresses.polygon.frakToken;
      foundationWallet = "0x517ecFa01E2F9A6955d8DD04867613E41309213d";
      metadataUrl = "https://metadata.frak.id/json/{id.json}";
    } else {
      throw new Error("Invalid network");
    }

    // Deploy Internal tokens
    const fraktionTokens = await deployContract<FraktionTokens>("FraktionTokens", [metadataUrl]);
    console.log(`Fraktion tokens deployed to ${fraktionTokens.address}`);

    // Deploy the reward pools
    const referralPool = await deployContract<ReferralPool>("ReferralPool", [erc20TokenAddr]);
    console.log(`Referral pool deployed to ${referralPool.address}`);
    const contentPool = await deployContract<ContentPool>("ContentPool", [erc20TokenAddr]);
    console.log(`Content pool deployed to ${contentPool.address}`);

    // Deploy the rewarder contract
    const rewarder = await deployContract<Rewarder>("Rewarder", [
      erc20TokenAddr,
      fraktionTokens.address,
      contentPool.address,
      referralPool.address,
      foundationWallet,
    ]);
    console.log(`Rewarder deployed to ${rewarder.address}`);

    // Deploy the minter contract
    const minter = await deployContract<Minter>("Minter", [erc20TokenAddr, fraktionTokens.address, foundationWallet]);
    console.log(`Minter deployed to ${minter.address}`);

    // Allow the rewarder contract as rearder for pools
    await referralPool.grantRole(rewarderRole, rewarder.address);
    await contentPool.grantRole(rewarderRole, rewarder.address);

    // Allow internal token to perform content related operation on the pool contract
    await contentPool.grantRole(tokenContractRole, fraktionTokens.address);

    // Grant the minting role to the minter contract
    await fraktionTokens.grantRole(minterRole, minter.address);

    // Build our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      fraktionTokens: fraktionTokens.address,
      referralPool: referralPool.address,
      contentPool: contentPool.address,
      rewarder: rewarder.address,
      minter: minter.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);

    console.log("Finished to deploy the eco system contracts");

    console.log("Starting to verify the deployed contracts");
    await hre.run("verify:verify", { address: fraktionTokens.address });
    await hre.run("verify:verify", { address: referralPool.address });
    await hre.run("verify:verify", { address: contentPool.address });
    await hre.run("verify:verify", { address: rewarder.address });
    await hre.run("verify:verify", { address: minter.address });
    console.log("Ended the contract verification");
  } catch (e: any) {
    console.log(e.message);
  }
})();
