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
    console.log("Starting to renounce to all of our deployer roles");

    const networkName = hre.hardhatArguments.network ?? "local";

    let addresses;
    if (networkName == "mumbai") {
      addresses = deployedAddresses.mumbai;
    } else if (networkName == "polygon") {
      addresses = deployedAddresses.polygon;
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

    const selfAddress = await frkToken.signer.getAddress();

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
    console.log(`Renounce to all the admin, pauser and upgrader roles`);
    const adminTxHashes: string[] = [];
    for (const contract of allContracts) {
      const adminRoleTx = await contract.renounceRole(adminRole, selfAddress);
      adminTxHashes.push(adminRoleTx.hash);
      await contract.renounceRole(pauserRole, selfAddress);
      await contract.renounceRole(upgraderRole, selfAddress);
    }

    console.log(`All the admin role tx's ${adminTxHashes}`);

    // Handle rewarder specific role
    await rewarder.renounceRole(rewarderRole, selfAddress);
    await rewarder.renounceRole(badgeUpdaterRole, selfAddress);

    // Handle minter specific role
    await minter.renounceRole(minterRole, selfAddress);
    await minter.renounceRole(badgeUpdaterRole, selfAddress);

    // Handle fraktion tokens specific role
    await minter.renounceRole(minterRole, selfAddress);

    // Handle frk token specific role
    await frkToken.renounceRole(minterRole, selfAddress);

    // Handle vesting specific roles
    await vestingFactory.renounceRole(vestingCreatorRole, selfAddress);
    await vestingWallets.renounceRole(vestingManagerRole, selfAddress);

    // Handle treasury specific role
    await treasuryWallet.renounceRole(minterRole, selfAddress);
  } catch (e: any) {
    console.log(e.message);
  }
})();
