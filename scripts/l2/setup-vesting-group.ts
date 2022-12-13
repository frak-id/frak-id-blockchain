import { BigNumber } from "ethers";

import * as deployedAddresses from "../../addresses.json";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { findContract } from "../utils/deploy";

const privateSaleGroupId = 1;
const publicSaleGroupId = 2;
const teamGroupId = 3;
const techAndDevGroupId = 4;
const marketGroupId = 5;
const creatorGrantsGroupId = 6;
const educationnalGroupId = 7;

const monthAsSecond = 2628002.88;

(async () => {
  try {
    console.log("Start to init our vesting groups");

    // Get our contract
    const vestingWalletFactory = await findContract<VestingWalletFactory>(
      "VestingWalletFactory",
      deployedAddresses.mumbai.vestingWalletFactory,
    );

    const decimals = BigNumber.from(10).pow(18);

    // Create the groups
    await vestingWalletFactory.addVestingGroup(privateSaleGroupId, decimals.mul(350_000_000), 0, monthToSecond(24));
    await vestingWalletFactory.addVestingGroup(publicSaleGroupId, decimals.mul(70_000_000), 0, monthToSecond(24));
    await vestingWalletFactory.addVestingGroup(teamGroupId, decimals.mul(250_000_000), 25, monthToSecond(36));
    await vestingWalletFactory.addVestingGroup(techAndDevGroupId, decimals.mul(150_000_000), 25, monthToSecond(36));
    /*await vestingWalletFactory.addVestingGroup(marketGroupId, decimals.mul(230_000_000), 10, monthToSecond(12), true);
    await vestingWalletFactory.addVestingGroup(
      creatorGrantsGroupId,
      decimals.mul(60_000_000),
      0,
      monthToSecond(1),
      false,
    );
    await vestingWalletFactory.addVestingGroup(
      educationnalGroupId,
      decimals.mul(60_000_000),
      0,
      monthToSecond(1),
      false,
    );*/

    console.log("Finished to init our vesting groups");
  } catch (e: any) {
    console.log(e.message);
  }
})();

function monthToSecond(month: number): BigNumber {
  const asSecond = month * monthAsSecond;
  return BigNumber.from(Math.round(asSecond));
}
