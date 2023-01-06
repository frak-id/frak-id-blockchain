import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken, FrakTreasuryWallet } from "../../types";
import { deployContract, findContract } from "../utils/deploy";
import { adminRole, minterRole, pauserRole, upgraderRole } from "../utils/roles";
import { updateContracts } from "../utils/updateContracts";

(async () => {
  try {
    console.log("Start to update our contracts to v1.0.1");

    // TODO : Deploy treasury here

    // Find the right addresses for our current network
    const networkName = hre.hardhatArguments.network ?? "local";
    const addresses = networkName === "mumbai" ? deployedAddresses.mumbai : deployedAddresses.polygon;
    const fireblocksAddr =
      networkName === "mumbai"
        ? "0x9f6f0915dA5452786A5A5Dc08fE5412a2981D746"
        : "0x97Ce46bBC97aa20D22Cf98b4E37775A55ff70cAC";

    // Find our frak token contract
    const frakToken = await findContract<FrakToken>("FrakToken", addresses.frakToken);

    // Deploy treasury wallet
    const treasuryWallet = await deployContract<FrakTreasuryWallet>("FrakTreasuryWallet", [addresses.frakToken]);
    console.log(`Treasury wallet was deployed to ${treasuryWallet.address}`);

    // Then verify our contract
    console.log("Verifying treasury contract");
    await hre.run("verify:verify", { address: treasuryWallet.address });

    // Grant the right role to the treasury wallet contract
    const grantRoleTx = await frakToken.grantRole(minterRole, treasuryWallet.address);
    console.log(`Granting minter role on tx ${grantRoleTx.hash}`);

    // Update our deployed address object
    const addressesMap: Map<string, any> = new Map(Object.entries(deployedAddresses));
    addressesMap.delete("default");
    addressesMap.set(networkName, {
      ...addressesMap.get(networkName),
      frakTreasuryWallet: treasuryWallet.address,
    });
    // Then wrote it into a file
    const jsonAddresses = JSON.stringify(Object.fromEntries(addressesMap));
    fs.writeFileSync("addresses.json", jsonAddresses);

    // Update our contracts
    const nameToAddresses = [
      { name: "Rewarder", address: addresses.rewarder },
      { name: "ContentPool", address: addresses.contentPool },
      { name: "ReferralPool", address: addresses.referralPool },
    ];
    await updateContracts(nameToAddresses);

    // Grant the admin roles on the treasury contract
    console.log("Granting the role to the fireblocks wallet");
    await treasuryWallet.grantRole(adminRole, fireblocksAddr);
    await treasuryWallet.grantRole(pauserRole, fireblocksAddr);
    await treasuryWallet.grantRole(upgraderRole, fireblocksAddr);
    await treasuryWallet.grantRole(minterRole, fireblocksAddr);

    // Grant the admin roles on the treasury contract
    console.log("Revoking the role of the deployer wallet");
    const selfAddress = await treasuryWallet.signer.getAddress();
    await treasuryWallet.renounceRole(adminRole, selfAddress);
    await treasuryWallet.renounceRole(pauserRole, selfAddress);
    await treasuryWallet.renounceRole(upgraderRole, selfAddress);
    await treasuryWallet.renounceRole(minterRole, selfAddress);

    console.log("Finished to update our contracts to v1.0.1");
  } catch (e: any) {
    console.log(e.message);
  }
})();
