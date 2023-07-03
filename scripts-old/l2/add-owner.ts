import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import {
  ContentPool,
  FrakToken,
  FrakTreasuryWallet,
  FraktionTokens,
  Minter,
  MultiVestingWallets,
  ReferralPool,
  Rewarder,
  VestingWalletFactory,
} from "../../types";
import { findContract } from "../utils/deploy";
import {
  adminRole,
  badgeUpdaterRole,
  minterRole,
  pauserRole,
  rewarderRole,
  upgraderRole,
  vestingCreatorRole,
  vestingManagerRole,
} from "../utils/roles";

(async () => {
  try {
    console.log("Starting to add our fireblocks as manager of our actions");

    const networkName = hre.hardhatArguments.network ?? "local";

    let addresses;
    let fireblocksAddr;
    if (networkName == "mumbai") {
      addresses = deployedAddresses.mumbai;
      fireblocksAddr = "0x9f6f0915dA5452786A5A5Dc08fE5412a2981D746";
    } else if (networkName == "polygon") {
      addresses = deployedAddresses.polygon;
      fireblocksAddr = "0x97Ce46bBC97aa20D22Cf98b4E37775A55ff70cAC";
    } else {
      throw new Error("Invalid network");
    }

    // Find our contracts
    const frkToken = await findContract<FrakToken>("FrakToken", addresses.frakToken);
    const fraktionTokens = await findContract<FraktionTokens>("FraktionTokens", addresses.fraktionTokens);
    const minter = await findContract<Minter>("Minter", addresses.minter);
    const rewarder = await findContract<Rewarder>("Rewarder", addresses.rewarder);
    const contentPool = await findContract<ContentPool>("ContentPool", addresses.contentPool);
    const referralPool = await findContract<ReferralPool>("ReferralPool", addresses.referralPool);
    const vestingWallets = await findContract<MultiVestingWallets>("MultiVestingWallets", addresses.multiVestingWallet);
    const vestingFactory = await findContract<VestingWalletFactory>(
      "VestingWalletFactory",
      addresses.vestingWalletFactory,
    );
    const treasuryWallet = await findContract<FrakTreasuryWallet>(
      "FrakTreasuryWallet",
      addresses.vestingWalletFactory, // TODO : To be replaced post deployment
    );

    // Get the array of all the contracts
    const allContracts = [
      frkToken,
      fraktionTokens,
      minter,
      rewarder,
      contentPool,
      referralPool,
      vestingWallets,
      vestingFactory,
      treasuryWallet,
    ];

    // Grant the admin role on all the contract (for the transaction executor)
    console.log(`Granting all the admin, pauser and upgrader roles`);
    const adminTxHashes: string[] = [];
    for (const contract of allContracts) {
      const adminRoleTx = await contract.grantRole(adminRole, fireblocksAddr);
      adminTxHashes.push(adminRoleTx.hash);
      await contract.grantRole(pauserRole, fireblocksAddr);
      await contract.grantRole(upgraderRole, fireblocksAddr);
    }

    console.log(`All the admin role tx's ${adminTxHashes}`);

    // Handle rewarder specific role
    await rewarder.grantRole(rewarderRole, fireblocksAddr);
    await rewarder.grantRole(badgeUpdaterRole, fireblocksAddr);

    // Handle minter specific role
    await minter.grantRole(minterRole, fireblocksAddr);
    await minter.grantRole(badgeUpdaterRole, fireblocksAddr);

    // Handle fraktion tokens specific role
    await minter.grantRole(minterRole, fireblocksAddr);

    // Handle frk token specific role
    await frkToken.grantRole(minterRole, fireblocksAddr);

    // Handle vesting specific roles
    await vestingFactory.grantRole(vestingCreatorRole, fireblocksAddr);
    await vestingWallets.grantRole(vestingManagerRole, fireblocksAddr);

    // Handle treasury specific role
    await treasuryWallet.grantRole(minterRole, fireblocksAddr);
  } catch (e: any) {
    console.log(e.message);
  }
})();
