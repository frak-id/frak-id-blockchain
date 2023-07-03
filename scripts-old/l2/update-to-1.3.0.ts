import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { updateContracts } from "../utils/updateContracts";

(async () => {
  try {
    console.log("Start to update our contracts to v1.3.0");

    // Find the right addresses for our current network
    const networkName = hre.hardhatArguments.network ?? "local";
    const addresses = networkName === "mumbai" ? deployedAddresses.mumbai : deployedAddresses.polygon;

    // Update our contracts
    const nameToAddresses = [
      { name: "Minter", address: addresses.minter },
      {
        name: "FrakToken",
        address: addresses.frakToken,
        call: {
          fn: "initializeV2()",
        },
      },
    ];
    await updateContracts(nameToAddresses);

    console.log("Finished to update our contracts to v1.3.0");
  } catch (e: any) {
    console.log(e.message);
  }
})();
