// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SybelTokenL1 } from "../../types/contracts/tokens/SybelTokenL1";
import { deployContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Deploying the SybelToken");
    // TODO : Ensure we are on the Ethereum blockchain ! ChainId of the provider or spmething like that
    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelTokenL1>("SybelTokenL1");
    console.log(`Sybel token L1 was deployed to ${sybelToken.address}`);
  } catch (e: any) {
    console.log(e.message);
  }
})();
