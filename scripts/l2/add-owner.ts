import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { ContentPool, Minter, MultiVestingWallets, ReferralPool, Rewarder, } from "../../types";
import { findContract } from "../utils/deploy";
import { adminRole, badgeUpdaterRole, minterRole, rewarderRole, vestingManagerRole } from "../utils/roles";

(async () => {
  try {
    console.log("Starting to add our fireblocks as manager of our actions");
    const fireblocksAddr = "0x9f6f0915dA5452786A5A5Dc08fE5412a2981D746";

    const sybelCorpWallet = (await hre.ethers.getSigners())[0].address;
    console.log(sybelCorpWallet);

    // Find our contracts
    const minter = await findContract<Minter>("Minter", deployedAddresses.mumbai.minter);
    const rewarder = await findContract<Rewarder>("Rewarder", deployedAddresses.mumbai.rewarder);
    const contentPool = await findContract<ContentPool>("ContentPool", deployedAddresses.mumbai.contentPool);
    const referralPool = await findContract<ReferralPool>("ReferralPool", deployedAddresses.mumbai.referralPool);
    const vestingWallets = await findContract<MultiVestingWallets>(
      "MultiVestingWallets",
      deployedAddresses.mumbai.referralPool,
    );

    // Add the right roles
    await minter.grantRole(minterRole, fireblocksAddr);
    await rewarder.grantRole(rewarderRole, fireblocksAddr);

    await minter.grantRole(badgeUpdaterRole, fireblocksAddr);
    await rewarder.grantRole(badgeUpdaterRole, fireblocksAddr);

    await rewarder.grantRole(adminRole, fireblocksAddr);
    await contentPool.grantRole(adminRole, fireblocksAddr);
    await referralPool.grantRole(adminRole, fireblocksAddr);

    await vestingWallets.grantRole(vestingManagerRole, fireblocksAddr);
  } catch (e: any) {
    console.log(e.message);
  }
})();
