import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { ContentPool, Minter, ReferralPool, Rewarder, SybelInternalTokens, SybelToken } from "../../types";
import { deployContract, findContract } from "../utils/deploy";
import { minterRole, rewarderRole, tokenContractRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the eco system contracts");
    const erc20TokenAddr = deployedAddresses.mumbai.sybelToken;

    // Find the erc 20 contract
    const sybelToken = await findContract<SybelToken>("SybelToken", erc20TokenAddr);

    // Deploy Internal tokens
    const internalToken = await deployContract<SybelInternalTokens>("SybelInternalTokens");

    // Deploy the reward pools
    const referralPool = await deployContract<ReferralPool>("ReferralPool", [erc20TokenAddr]);
    const contentPool = await deployContract<ContentPool>("ContentPool", [erc20TokenAddr]);

    // The foundation wallet addr
    // TODO : Should be changed for production
    const fondationWallet = "0x8Cb488e0E16e49F064e210969EE1c771a55BcD04";

    // Deploy the rewarder contract
    const rewarder = await deployContract<Rewarder>("Rewarder", [
      erc20TokenAddr,
      internalToken.address,
      referralPool.address,
      contentPool.address,
      fondationWallet,
    ]);

    // Deploy the minter contract
    const minter = await deployContract<Minter>("Minter", [erc20TokenAddr, internalToken.address, fondationWallet]);

    // Allow the rewarder contract to mint frak token
    await sybelToken.grantRole(minterRole, rewarder.address);

    // Allow the rewarder contract as rearder for pools
    await referralPool.grantRole(rewarderRole, rewarder.address);
    await contentPool.grantRole(rewarderRole, rewarder.address);

    // Allow internal token to perform content related operation on the pool contract
    await contentPool.grantRole(tokenContractRole, internalToken.address);

    // Grant the minting role to the minter contract
    await internalToken.grantRole(minterRole, minter.address);

    // Build our deployed address object
    const networkName = hre.hardhatArguments.network ?? "local";
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      internalToken: internalToken.address,
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
    await hre.run("verify:verify", { address: internalToken.address });
    await hre.run("verify:verify", { address: referralPool.address });
    await hre.run("verify:verify", { address: contentPool.address });
    await hre.run("verify:verify", { address: rewarder.address });
    await hre.run("verify:verify", { address: minter.address });
    console.log("Ended the contract verification");
  } catch (e: any) {
    console.log(e.message);
  }
})();
