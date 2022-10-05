import { utils } from "ethers";

export const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000";
export const minterRole = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));
export const upgraderRole = utils.keccak256(utils.toUtf8Bytes("UPGRADER_ROLE"));
export const pauserRole = utils.keccak256(utils.toUtf8Bytes("PAUSER_ROLE"));
export const rewarderRole = utils.keccak256(utils.toUtf8Bytes("REWARDER_ROLE"));
export const badgeUpdaterRole = utils.keccak256(utils.toUtf8Bytes("BADGE_UPDATER_ROLE"));
