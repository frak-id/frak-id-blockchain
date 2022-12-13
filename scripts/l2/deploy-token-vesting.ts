import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken, MultiVestingWallets, VestingWalletFactory } from "../../types";
import { deployContract } from "../utils/deploy";
import { vestingManagerRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the FrakToken and the VestingWallet");
    const networkName = hre.hardhatArguments.network ?? "local";
    // Get the right child manager proxy depending on the env
    let childManagerProxy: string;
    if (networkName == "mumbai") {
      childManagerProxy = "0xb5505a6d998549090530911180f38aC5130101c6";
    } else if (networkName == "polygon") {
      childManagerProxy = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";
    } else {
      throw new Error("Invalid network");
    }
    // Deploy our sybl token contract
    const frakToken = await deployContract<FrakToken>("FrakToken", [childManagerProxy]);
    console.log(`Frak token L2 was deployed to ${frakToken.address}`);
    // Deploy vesting wallet and vesting wallt factory
    const multiVestingWallet = await deployContract<MultiVestingWallets>("MultiVestingWallets", [frakToken.address]);
    console.log(`Multi vesting wallet was deployed to ${multiVestingWallet.address}`);

    const vestingWalletFactory = await deployContract<VestingWalletFactory>("VestingWalletFactory", [
      multiVestingWallet.address,
    ]);
    console.log("Vesting wallet was deployed to " + vestingWalletFactory.address);

    // Grant the vesting manager role to the vesting factory
    await multiVestingWallet.grantRole(vestingManagerRole, vestingWalletFactory.address);
    console.log("Vesting wallet has now the manager role on the multi-vesting wallet");

    // Build our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      frakToken: frakToken.address,
      multiVestingWallet: multiVestingWallet.address,
      vestingWalletFactory: vestingWalletFactory.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);

    console.log("Finished to deploy the FrakToken and the VestingWallet");

    // Finally, check them
    console.log("Starting to verify the deployed contracts");
    await hre.run("verify:verify", { address: frakToken.address });
    await hre.run("verify:verify", { address: multiVestingWallet.address });
    await hre.run("verify:verify", { address: vestingWalletFactory.address });
    console.log("Ended the contract verification");
  } catch (e: any) {
    console.log(e.message);
  }
})();
