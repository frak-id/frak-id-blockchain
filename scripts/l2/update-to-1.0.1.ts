import hre, { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { updateContracts } from "../utils/updateContracts";

(async () => {
  try {
    console.log("Start to update our contracts to v1.0.1");

    // TODO : Deploy treasury here

    // Update our push and pull reward contract

    const nameToAddresses = [
      { name: "Rewarder", address: deployedAddresses.polygon.rewarder },
      { name: "ContentPool", address: deployedAddresses.polygon.contentPool },
      { name: "ReferralPool", address: deployedAddresses.polygon.referralPool },
    ];

    // Get our contract factory and update it
    await updateContracts(nameToAddresses);

    console.log("Finished to update our contracts to v1.0.1");
  } catch (e: any) {
    console.log(e.message);
  }
})();
