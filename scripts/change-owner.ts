// This script can be used to deploy the "PodcastHandler" contract using Web3 library.
import { BaseContract, BytesLike, Contract, ContractTransaction, Overrides, utils } from "ethers";
import { ethers } from "hardhat";

import * as addr from "../../shared/addresses.json";
import { PromiseOrValue } from "../types/common";
import { FractionCostBadges } from "../types/contracts/badges/cost/FractionCostBadges";
import { ListenerBadges } from "../types/contracts/badges/payment/ListenerBadges";
import { PodcastBadges } from "../types/contracts/badges/payment/PodcastBadges";
import { Minter } from "../types/contracts/minter/Minter";
import { Rewarder } from "../types/contracts/reward/Rewarder";
import { SybelInternalTokens } from "../types/contracts/tokens/SybelInternalTokens";
import { SybelToken } from "../types/contracts/tokens/SybelTokenL2.sol/SybelToken";
import { FoundationWallet } from "../types/contracts/wallets/FoundationWallet";

let adminRole = "0x00";
const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
const upgraderRole = utils.keccak256(utils.toUtf8Bytes("UPGRADER_ROLE"));
const pauserRole = utils.keccak256(utils.toUtf8Bytes("PAUSER_ROLE"));
const rewarderRole = utils.keccak256(utils.toUtf8Bytes("REWARDER_ROLE"));
const badgeUpdaterRole = utils.keccak256(utils.toUtf8Bytes("BADGE_UPDATER_ROLE"));

(async () => {
  try {
    console.log("Deploying all the contract for a simple blockchain intergration");

    // Find the previous owner
    const previousOwner = "0xDAD64D2dEDBe40796EA5099F557C5Bb2490568Ae";
    const newOwner = "0x7caF754C934710D7C73bc453654552BEcA38223F";

    console.log(`Updating from ${previousOwner} to ${newOwner}`);

    // Find all of our contract
    const minter = await findContract<Minter>("Minter", addr.minterAddr);
    const rewarder = await findContract<Rewarder>("Rewarder", addr.rewarderAddr);
    const fractions = await findContract<FractionCostBadges>("FractionCostBadges", addr.fractionCostBadgesAddr);
    const listener = await findContract<ListenerBadges>("ListenerBadges", addr.listenBadgesAddr);
    const podcast = await findContract<PodcastBadges>("PodcastBadges", addr.podcastBadgesAddr);
    const sybelToken = await findContract<SybelToken>("SybelToken", addr.sybelTokenAddr);
    const internalToken = await findContract<SybelInternalTokens>("SybelInternalTokens", addr.internalTokenAddr);
    const fondation = await findContract<FoundationWallet>("FoundationWallet", addr.fondationWalletAddr);

    adminRole = await minter.DEFAULT_ADMIN_ROLE();

    // Update all the minter contracts
    await updateMinterContract(minter, newOwner, previousOwner);
    await updateMinterContract(sybelToken, newOwner, previousOwner);
    await updateMinterContract(internalToken, newOwner, previousOwner);

    // Update all the badges contracts
    await updateRolesContract(fractions, newOwner, previousOwner, [
      pauserRole,
      upgraderRole,
      badgeUpdaterRole,
      adminRole,
    ]);
    await updateRolesContract(listener, newOwner, previousOwner, [
      pauserRole,
      upgraderRole,
      badgeUpdaterRole,
      adminRole,
    ]);
    await updateRolesContract(podcast, newOwner, previousOwner, [
      pauserRole,
      upgraderRole,
      badgeUpdaterRole,
      adminRole,
    ]);

    // Update rewarder contract
    await updateRolesContract(rewarder, newOwner, previousOwner, [pauserRole, upgraderRole, rewarderRole, adminRole]);
    await updateRolesContract(fondation, newOwner, previousOwner, [pauserRole, upgraderRole, rewarderRole, adminRole]);

    console.log(`Finished the update from ${previousOwner} to ${newOwner}`);
  } catch (e) {
    console.log(e);
  }
})();

async function findContract<Type extends Contract>(name: string, address: string): Promise<Type> {
  const contractFactory = await ethers.getContractFactory(name);
  return contractFactory.attach(address) as Type;
}

// For Minter, internal token, sybel tokens
async function updateMinterContract(
  contract: RoleAwareContract,
  newOwner: string,
  previousOwner: string,
): Promise<void> {
  await updateRolesContract(contract, newOwner, previousOwner, [pauserRole, upgraderRole, minterRole, adminRole]);
}

// For Minter, internal token, sybel tokens
async function updateRolesContract(
  contract: RoleAwareContract,
  newOwner: string,
  previousOwner: string,
  roles: BytesLike[],
): Promise<void> {
  console.log(`Updating contract at ${contract.address}`);

  for (const role of roles) {
    await updateForFole(contract, newOwner, previousOwner, role);
  }

  console.log(`Endend the contract update at ${contract.address}`);
}

async function updateForFole(
  contract: RoleAwareContract,
  newOwner: string,
  previousOwner: string,
  role: BytesLike,
): Promise<void> {
  console.log(`Updating contract role ${role} for contract ${contract.address}`);

  const grantRoleTx = await contract.grantRole(role, newOwner);
  const renounceRoleTx = await contract.revokeRole(role, previousOwner);

  console.log(`Grant role TX ${grantRoleTx.hash}`);
  console.log(`Revoke role TX ${renounceRoleTx.hash}`);

  console.log(`Ended role ${role} update for the contract ${contract.address} for role `);
}

interface RoleAwareContract extends BaseContract {
  grantRole(
    role: PromiseOrValue<BytesLike>,
    account: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> },
  ): Promise<ContractTransaction>;

  revokeRole(
    role: PromiseOrValue<BytesLike>,
    account: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> },
  ): Promise<ContractTransaction>;
}
