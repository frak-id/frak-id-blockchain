import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken, FrakTreasuryWallet } from "../../types";
import { deployContract, findContract } from "../utils/deploy";
import { minterRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the Treasury wallet");
    const networkName = hre.hardhatArguments.network ?? "local";
    // Get the right child manager proxy depending on the env
    let frkTokenAddr: string;
    if (networkName == "mumbai") {
      frkTokenAddr = deployedAddresses.mumbai.frakToken;
    } else if (networkName == "polygon") {
      frkTokenAddr = deployedAddresses.polygon.frakToken;
    } else {
      throw new Error("Invalid network");
    }
    // Deploy our frk token contract
    const frakToken = await findContract<FrakToken>("FrakToken", frkTokenAddr);
    // Deploy treasury wallet
    const treasuryWallet = await deployContract<FrakTreasuryWallet>("FrakTreasuryWallet", [frakToken.address]);
    console.log(`Treasury wallet was deployed to ${treasuryWallet.address}`);

    // Build our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      frakTreasuryWallet: treasuryWallet.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);

    // Grant the minting role to the treasury wallet
    const grantRoleTx = await frakToken.grantRole(minterRole, treasuryWallet.address);
    console.log(`FrkToken minter role grant to Treasury wallet on the tx ${grantRoleTx.hash}`);

    console.log("Finished to deploy the Treasury wallet");

    // Finally, check them
    console.log("Starting to verify the deployed contracts");
    await hre.run("verify:verify", { address: treasuryWallet.address });
    console.log("Ended the contract verification");
  } catch (e: any) {
    console.log(e.message);
  }
})();
