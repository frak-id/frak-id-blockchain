import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { Minter } from "../../types/contracts/minter/Minter";
import { Rewarder } from "../../types/contracts/reward/Rewarder";
import { ContentPool } from "../../types/contracts/reward/pool/ContentPool";
import { ReferralPool } from "../../types/contracts/reward/pool/ReferralPool";
import { SybelInternalTokens } from "../../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { deployContract, findContract } from "../utils/deploy";
import { minterRole, rewarderRole, tokenContractRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the eco system contracts");
    const erc20TokenAddr = deployedAddresses.l2.sybelToken;

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
      fondationWallet
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

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      l2: {
        ...deployedAddresses.l2,
        internalToken: internalToken.address,
        referralPool: referralPool.address,
        contentPool: contentPool.address,
        rewarder: rewarder.address,
        minter: minter.address,
        default: null,
      },
      default: null,
    };
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);

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
