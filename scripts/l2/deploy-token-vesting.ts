// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { SybelToken } from "../../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { MultiVestingWallets } from "../../types/contracts/wallets/MultiVestingWallets";
import { VestingWalletFactory } from "../../types/contracts/wallets/VestingWalletFactory";
import { deployContract } from "../utils/deploy";

(async () => {
  try {
    console.log("Deploygin the SybelToken and the VestingWallet");
    // TODO : Ensure we are on the Polygon blockchain ! ChainId of the provider or spmething like that
    // Deploy our sybl token contract
    const sybelToken = await deployContract<SybelToken>("SybelToken");
    console.log(`Sybel token L2 was deployed to ${sybelToken.address}`);
    // Deploy vesting wallet and vesting wallt factory
    const multiVestingWallet = await deployContract<MultiVestingWallets>("MultiVestingWallets");
    console.log(`Multi vesting wallet was deployed to ${multiVestingWallet.address}`);
    const vestingWalletFactory = await deployContract<VestingWalletFactory>("VestingWalletFactory");
    console.log("Vesting wallet was deployed to " + vestingWalletFactory.address);
  } catch (e: any) {
    console.log(e.message);
  }
})();
