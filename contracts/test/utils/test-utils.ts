import { ethers } from "hardhat";
import { BigNumber, BigNumberish, ContractTransaction } from "ethers";

export const address0 = "0x0000000000000000000000000000000000000000";

export async function updateTimestampToEndOfDuration(tx: ContractTransaction, duration?: BigNumberish) {
  // Wait for the tx to be mined
  await tx.wait();
  const txMined = await ethers.provider.getTransaction(tx.hash);
  const blockHash = txMined.blockHash;
  if (!blockHash) return;
  const blockTimestamp = (await ethers.provider.getBlock(blockHash)).timestamp;
  // Exit if we add no addition duration
  if (!duration) return;
  // Get the investor group duration
  const newTimestamp = BigNumber.from(blockTimestamp).add(duration).toNumber();
  // Increase the blockchain timestamp
  await ethers.provider.send("evm_mine", [newTimestamp]);
}

export async function updatToGivenTimestamp(timestamp: number) {
  await ethers.provider.send("evm_mine", [timestamp]);
}

export async function getTimestampInAFewMoment(): Promise<number> {
  const currentTimestamp = (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp;
  return currentTimestamp + 100;
}
