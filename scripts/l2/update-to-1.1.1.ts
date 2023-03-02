import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { updateContracts } from "../utils/updateContracts";

(async () => {
  try {
    console.log("Start to update our contracts to v1.1.1");

    // Find the right addresses for our current network
    const networkName = hre.hardhatArguments.network ?? "local";
    const addresses = networkName === "mumbai" ? deployedAddresses.mumbai : deployedAddresses.polygon;

    // Update our contracts
    const nameToAddresses = [
      { name: "Minter", address: addresses.minter },
      { name: "FraktionTokens", address: addresses.fraktionTokens },
    ];
    await updateContracts(nameToAddresses);

    console.log("Finished to update our contracts to v1.1.1");
  } catch (e: any) {
    console.log(e.message);
  }
})();
