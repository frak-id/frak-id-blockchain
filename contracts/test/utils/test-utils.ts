import { ethers } from "hardhat";
import { BigNumber, BigNumberish, ContractTransaction } from "ethers";

export async function updateTimestampToEndOfDuration(tx: ContractTransaction, duration: BigNumberish) {
  // Wait for the tx to be mined
  await tx.wait();
  const txMined = await ethers.provider.getTransaction(tx.hash);
  const blockHash = txMined.blockHash;
  if (!blockHash) return;
  const blockTimestamp = (await ethers.provider.getBlock(blockHash)).timestamp;
  // Get the investor group duration
  const newTimestamp = BigNumber.from(blockTimestamp).add(duration).toNumber();
  // Increase the blockchain timestamp
  await ethers.provider.send("evm_mine", [newTimestamp]);
}
