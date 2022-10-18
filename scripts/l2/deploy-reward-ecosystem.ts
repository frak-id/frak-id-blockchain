import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FractionCostBadges } from "../../types/contracts/badges/cost/FractionCostBadges";
import { ContentBadges } from "../../types/contracts/badges/payment/ContentBadges";
import { ListenerBadges } from "../../types/contracts/badges/payment/ListenerBadges";
import { deployContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Starting to deploy the SybelToken and the VestingWallet");
    // TODO : Deploy badges
    const listenerBadges = await deployContract<ListenerBadges>("ListenerBadges");
    const contentBadges = await deployContract<ContentBadges>("ContentBadges");
    const fractionCostBadges = await deployContract<FractionCostBadges>("FractionCostBadges");

    // TODO : Deploy Internal Token
    // TODO : Deploy Rewarder and minter

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      l2: {
        ...deployedAddresses.l2,
        listenerBadges: listenerBadges.address,
        contentBadges: contentBadges.address,
        fractionCostBadges: fractionCostBadges.address,
        default: null,
      },
      default: null,
    };
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(addresses);
    fs.writeFileSync("addresses.json", jsonAddresses);
    fs.writeFileSync(`addresses-${hre.hardhatArguments.network}.json`, jsonAddresses);

    console.log("Finished to deploy the SybelToken and the VestingWallet");
  } catch (e: any) {
    console.log(e.message);
  }
})();
