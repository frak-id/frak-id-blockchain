import { Contract } from "ethers";
import hre, { ethers, upgrades } from "hardhat";

export async function updateContracts(
  contracts: {
    name: string;
    address: string;
    call?: { fn: string; args?: unknown[] };
  }[],
) {
  console.log(" - Start to update our contracts");

  // Array of promise for our contract deployment
  const deployedPromises = [];

  // Get our contract factory and update all of our contract
  for (const nameToAddress of contracts) {
    console.log(` -- Launching contract ${nameToAddress.name} update`);
    try {
      // Get our contract factory
      const contractFactory = await ethers.getContractFactory(nameToAddress.name);
      const contract = await upgrades.upgradeProxy(nameToAddress.address, contractFactory, {
        unsafeAllowRenames: true,
        call: nameToAddress.call,
      });
      // Save the deployment promise for further waiting
      deployedPromises.push(contract.deployed());
    } catch (e) {
      console.log(` - An error occured while deploying the contract  ${nameToAddress.name} : ${e}`);
    }
  }

  // Wait for all the contract to be deployed
  console.log(` - Waiting for all contracts to be deployed`);
  const deployedContracts = await Promise.all(deployedPromises);

  // Verify all contracts
  console.log(` - Verifying all deployed contracts`);
  const verifiedPromise = deployedContracts.map(async contract => {
    try {
      console.log(` -- Verifying contract at ${contract.address}`);
      await hre.run("verify:verify", { address: contract.address });
    } catch (e) {
      console.log(` -- Error when verifying contract at ${contract.address}`);
    }
  });
  await Promise.all(verifiedPromise);

  console.log(" - Finished to update our contracts");
}
