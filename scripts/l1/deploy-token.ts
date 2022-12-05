import fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { SybelTokenL1 } from "../../types";
import { deployContract } from "../utils/deploy";
import { predicateRole } from "../utils/roles";

(async () => {
  try {
    console.log("Deploying the SybelToken");
    const networkName = hre.hardhatArguments.network ?? "local";

    // Get the right child predicate depending on the env
    let predicateProxyAddr: string;
    if (networkName == "goerli") {
      predicateProxyAddr = "0x37c3bfC05d5ebF9EBb3FF80ce0bd0133Bf221BC8";
    } else if (networkName == "ethereum") {
      predicateProxyAddr = "0x9923263fA127b3d1484cFD649df8f1831c2A74e4";
    } else {
      throw new Error("Invalid network");
    }

    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelTokenL1>("SybelTokenL1");
    console.log(`Sybel token L1 was deployed to ${sybelToken.address}`);

    // Grant the role to the predicate proxy
    await sybelToken.grantRole(predicateRole, predicateProxyAddr);

    // Build our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      sybelToken: sybelToken.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);
  } catch (e: any) {
    console.log(e.message);
  }
})();
