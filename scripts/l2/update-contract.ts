import hre, { ethers, upgrades } from "hardhat";

import * as deployedAddresses from "../../addresses.json";

(async () => {
  try {
    console.log("Start to update one of our contract");

    const nameToAddresses = [
      { name: "FrakToken", address: deployedAddresses.polygon.frakToken },
      { name: "MultiVestingWallets", address: deployedAddresses.polygon.multiVestingWallet },
      { name: "VestingWalletFactory", address: deployedAddresses.polygon.vestingWalletFactory },
    ]

    // Get our contract factory and update it
    for (let nameToAddress of nameToAddresses) {
      console.log(`Handling ${nameToAddress.name} updates`)
      const contractFactory = await ethers.getContractFactory(nameToAddress.name);
      const contract = await upgrades.upgradeProxy(nameToAddress.address, contractFactory);
      await contract.deployed();

      await hre.run("verify:verify", { address: contract.address });
    }

    console.log("Finished to update one of our contract");
  } catch (e: any) {
    console.log(e.message);
  }
})();
