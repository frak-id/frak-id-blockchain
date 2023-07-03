import { BigNumber } from "ethers";
import hre from "hardhat";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken, Rewarder } from "../../types";
import { findContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Start to fake some rewards");
    const networkName = hre.hardhatArguments.network ?? "local";
    console.log(networkName)

    const rewarderAddr = deployedAddresses.mumbai.rewarder;

    // Find the erc 20 contract
    const rewarder = await findContract<Rewarder>("Rewarder", rewarderAddr);

    const payTx = await rewarder.payUser(
      "0xe4959298c6aB9C811C80F0BF74aabE7Af95062A6",
      BigNumber.from(1),
      [BigNumber.from(3)],
      [BigNumber.from(100)]
    );
    console.log("Paying listening token on the tx " + payTx.hash);

    // Find the erc 20 contract
    const frakToken = await findContract<FrakToken>("FrakToken", deployedAddresses.mumbai.frakToken);

    const mintTx = await frakToken.mint(
      "0xe4959298c6aB9C811C80F0BF74aabE7Af95062A6",
      BigNumber.from(10).pow(18).mul(500),
    );

    console.log("Minting token on the tx " + mintTx.hash);

    console.log("Finished to fake some rewards");
  } catch (e: any) {
    console.log(e.message);
  }
})();
