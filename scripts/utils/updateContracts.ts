import hre, { ethers, upgrades } from "hardhat";

export async function updateContracts(
  contracts: {
    name: string;
    address: string;
  }[],
) {
  console.log("Start to update our contracts");

  // Get our contract factory and update it
  for (let nameToAddress of contracts) {
    console.log(`Handling ${nameToAddress.name} updates`);
    const contractFactory = await ethers.getContractFactory(nameToAddress.name);
    const contract = await upgrades.upgradeProxy(nameToAddress.address, contractFactory);
    await contract.deployed();

    await hre.run("verify:verify", { address: contract.address });
  }

  console.log("Finished to update our contracts");
}
