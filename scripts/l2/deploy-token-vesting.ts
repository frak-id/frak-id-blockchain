import * as fs from "fs";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { deployContract } from "../utils/deploy";
import { vestingManagerRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to deploy the SybelToken and the VestingWallet");
    // Deploy our sybl token contract
    const childManagerProxy = "0xb5505a6d998549090530911180f38aC5130101c6";
    // mainnet proxy :
    // const childManagerProxy = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";
    const sybelToken = await deployContract<SybelToken>("SybelToken", [childManagerProxy]);
    console.log(`Sybel token L2 was deployed to ${sybelToken.address}`);
    // Deploy vesting wallet and vesting wallt factory
    const multiVestingWallet = await deployContract<MultiVestingWallets>("MultiVestingWallets", [sybelToken.address]);
    console.log(`Multi vesting wallet was deployed to ${multiVestingWallet.address}`);

    const vestingWalletFactory = await deployContract<VestingWalletFactory>("VestingWalletFactory", [
      sybelToken.address,
      multiVestingWallet.address,
    ]);
    console.log("Vesting wallet was deployed to " + vestingWalletFactory.address);

    // Grant the vesting manager role to the vesting factory
    await multiVestingWallet.grantRole(vestingManagerRole, vestingWalletFactory.address);
    console.log("Vesting wallet has now the manager role on the muyltivesting wallet");

    // Build our deplyoed address object
    const addresses = {
      ...deployedAddresses,
      l2: {
        sybelToken: sybelToken.address,
        multiVestingWallet: multiVestingWallet.address,
        vestingWalletFactory: vestingWalletFactory.address,
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
