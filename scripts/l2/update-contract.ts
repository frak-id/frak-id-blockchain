import { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";

(async () => {
  try {
    console.log("Start to update one of our contract");

    // Get our contract factory and update it
    const contractFactory = await ethers.getContractFactory("Minter");
    const contract = await upgrades.upgradeProxy(deployedAddresses.mumbai.minter, contractFactory);
    await contract.deployed();

    console.log("Finished to update one of our contract");
  } catch (e: any) {
    console.log(e.message);
  }
})();
