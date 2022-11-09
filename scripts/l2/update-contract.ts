import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { findContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Start to update one of our contract");

    // Get our contract factory and update it
    const contractFactory = await ethers.getContractFactory("Minter");
    const contract = await upgrades.upgradeProxy(deployedAddresses.l2.minter, contractFactory);
    await contract.deployed();

    console.log("Finished to update one of our contract");
  } catch (e: any) {
    console.log(e.message);
  }
})();
