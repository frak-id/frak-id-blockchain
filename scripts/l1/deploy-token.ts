import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { SybelTokenL1 } from "../../types/contracts/tokens/SybelTokenL1";
import { deployContract } from "../utils/deploy";
import { predicateRole } from "../utils/roles";

(async () => {
  try {
    console.log("Deploying the SybelToken");
    // TODO : Ensure we are on the Ethereum blockchain ! ChainId of the provider or spmething like that
    // Deploy our sybl token contract

    const sybelToken = await deployContract<SybelTokenL1>("SybelTokenL1");
    console.log(`Sybel token L1 was deployed to ${sybelToken.address}`);

    const predicateProxyAddr = "0x37c3bfC05d5ebF9EBb3FF80ce0bd0133Bf221BC8";
    // const predicateProxyRole = "0x9923263fA127b3d1484cFD649df8f1831c2A74e4"; // TODO : For mainnet deployment

    await sybelToken.grantRole(predicateRole, predicateProxyAddr);

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      l1: {
        sybelToken: sybelToken.address,
      },
      default: null,
    };
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);
  } catch (e: any) {
    console.log(e.message);
  }
})();
