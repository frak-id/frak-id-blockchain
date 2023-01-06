import * as fs from "fs";
import hre, { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken, FrakTreasuryWallet } from "../../types";
import { deployContract, findContract } from "../utils/deploy";
import { updateContracts } from "../utils/updateContracts";

import * as fs from "fs";
import { minterRole } from "../utils/roles";

(async () => {
  try {
    console.log("Start to update our contracts to v1.0.1");

    // TODO : Deploy treasury here

    // Find the right addresses for our current network
    const networkName = hre.hardhatArguments.network ?? "local";
    const addresses = networkName === "mumbai" ? deployedAddresses.mumbai : deployedAddresses.polygon;

    // Find our frak token contract
    const frakToken = await findContract<FrakToken>("FrakToken", addresses.frakToken);

    // Deploy treasury wallet
    const treasuryWallet = await deployContract<FrakTreasuryWallet>("FrakTreasuryWallet", [addresses.frakToken]);
    console.log(`Treasury wallet was deployed to ${treasuryWallet.address}`);

    // Then verify our contract
    console.log("Verifying treasury contract")
    await hre.run("verify:verify", { address: treasuryWallet.address });

    // Grant the right role to the treasury wallet contract
    const grantRoleTx = await frakToken.grantRole(minterRole, treasuryWallet.address);
    console.log(`Granting minter role on tx ${grantRoleTx.hash}`)

    // Update our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      frakTreasuryWallet: treasuryWallet.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);

    // Update our contracts
    const nameToAddresses = [
      { name: "Rewarder", address: addresses.rewarder },
      { name: "ContentPool", address: addresses.contentPool },
      { name: "ReferralPool", address: addresses.referralPool },
    ];
    await updateContracts(nameToAddresses);

    console.log("Finished to update our contracts to v1.0.1");
  } catch (e: any) {
    console.log(e.message);
  }
})();
