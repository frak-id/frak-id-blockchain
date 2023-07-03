import { BigNumber } from "ethers";

import * as deployedAddresses from "../../addresses.json";
import { FrakToken } from "../../types";
import { findContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Start to mint some tokens");

    const erc20TokenAddr = deployedAddresses.mumbai.frakToken;

    // Find the erc 20 contract
    const frakToken = await findContract<FrakToken>("FrakToken", erc20TokenAddr);

    const mintTx = await frakToken.mint(
      "0xC442bc81106704628B87AC71781D4CCAD4b00132",
      BigNumber.from(10).pow(18).mul(500),
    );

    console.log("Minting token on the tx " + mintTx.hash);

    console.log("Finished to update one of our contract");
  } catch (e: any) {
    console.log(e.message);
  }
})();
