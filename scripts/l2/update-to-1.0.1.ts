import hre, { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { updateContracts } from "../utils/updateContracts";

(async () => {
  try {
    console.log("Start to update our contracts to v1.0.1");

    // TODO : Deploy treasury here

    // Update our push and pull reward contract
    const networkName = hre.hardhatArguments.network ?? "local";
    const addresses = networkName === "mumbai" ? deployedAddresses.mumbai : deployedAddresses.polygon;

    const nameToAddresses = [
      { name: "Rewarder", address: addresses.rewarder },
      { name: "ContentPool", address: addresses.contentPool },
      { name: "ReferralPool", address: addresses.referralPool },
    ];

    // Get our contract factory and update it
    await updateContracts(nameToAddresses);

    console.log("Finished to update our contracts to v1.0.1");
  } catch (e: any) {
    console.log(e.message);
  }
})();
