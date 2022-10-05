/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { ethers } from "ethers";
import {
  FactoryOptions,
  HardhatEthersHelpers as HardhatEthersHelpersBase,
} from "@nomiclabs/hardhat-ethers/types";

import * as Contracts from ".";

declare module "hardhat/types/runtime" {
  interface HardhatEthersHelpers extends HardhatEthersHelpersBase {
    getContractFactory(
      name: "AccessControlUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.AccessControlUpgradeable__factory>;
    getContractFactory(
      name: "IAccessControlUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IAccessControlUpgradeable__factory>;
    getContractFactory(
      name: "PaymentSplitterUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.PaymentSplitterUpgradeable__factory>;
    getContractFactory(
      name: "IERC1822ProxiableUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC1822ProxiableUpgradeable__factory>;
    getContractFactory(
      name: "IERC2981Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC2981Upgradeable__factory>;
    getContractFactory(
      name: "IBeaconUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IBeaconUpgradeable__factory>;
    getContractFactory(
      name: "ERC1967UpgradeUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC1967UpgradeUpgradeable__factory>;
    getContractFactory(
      name: "Initializable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Initializable__factory>;
    getContractFactory(
      name: "UUPSUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.UUPSUpgradeable__factory>;
    getContractFactory(
      name: "ERC1155Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC1155Upgradeable__factory>;
    getContractFactory(
      name: "IERC1155MetadataURIUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC1155MetadataURIUpgradeable__factory>;
    getContractFactory(
      name: "IERC1155ReceiverUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC1155ReceiverUpgradeable__factory>;
    getContractFactory(
      name: "IERC1155Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC1155Upgradeable__factory>;
    getContractFactory(
      name: "ERC20Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC20Upgradeable__factory>;
    getContractFactory(
      name: "IERC20PermitUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20PermitUpgradeable__factory>;
    getContractFactory(
      name: "IERC20MetadataUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20MetadataUpgradeable__factory>;
    getContractFactory(
      name: "IERC20Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20Upgradeable__factory>;
    getContractFactory(
      name: "ContextUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ContextUpgradeable__factory>;
    getContractFactory(
      name: "ERC165Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC165Upgradeable__factory>;
    getContractFactory(
      name: "IERC165Upgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC165Upgradeable__factory>;
    getContractFactory(
      name: "VestingWallet",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.VestingWallet__factory>;
    getContractFactory(
      name: "IERC20Permit",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20Permit__factory>;
    getContractFactory(
      name: "IERC20",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20__factory>;
    getContractFactory(
      name: "PaymentBadgesAccessor",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.PaymentBadgesAccessor__factory>;
    getContractFactory(
      name: "FractionCostBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.FractionCostBadges__factory>;
    getContractFactory(
      name: "IFractionCostBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IFractionCostBadges__factory>;
    getContractFactory(
      name: "IListenerBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IListenerBadges__factory>;
    getContractFactory(
      name: "IPodcastBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IPodcastBadges__factory>;
    getContractFactory(
      name: "ListenerBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ListenerBadges__factory>;
    getContractFactory(
      name: "PodcastBadges",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.PodcastBadges__factory>;
    getContractFactory(
      name: "IMinter",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IMinter__factory>;
    getContractFactory(
      name: "Minter",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Minter__factory>;
    getContractFactory(
      name: "ContentPool",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ContentPool__factory>;
    getContractFactory(
      name: "ContentPool",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ContentPool__factory>;
    getContractFactory(
      name: "ContentPoolReview",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ContentPoolReview__factory>;
    getContractFactory(
      name: "IRewarder",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IRewarder__factory>;
    getContractFactory(
      name: "Referral",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Referral__factory>;
    getContractFactory(
      name: "Rewarder",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Rewarder__factory>;
    getContractFactory(
      name: "SybelInternalTokens",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SybelInternalTokens__factory>;
    getContractFactory(
      name: "SybelToken",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SybelToken__factory>;
    getContractFactory(
      name: "IPausable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IPausable__factory>;
    getContractFactory(
      name: "MintingAccessControlUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.MintingAccessControlUpgradeable__factory>;
    getContractFactory(
      name: "SybelAccessControlUpgradeable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SybelAccessControlUpgradeable__factory>;
    getContractFactory(
      name: "FoundationWallet",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.FoundationWallet__factory>;
    getContractFactory(
      name: "VestingWallets",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.VestingWallets__factory>;

    getContractAt(
      name: "AccessControlUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.AccessControlUpgradeable>;
    getContractAt(
      name: "IAccessControlUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IAccessControlUpgradeable>;
    getContractAt(
      name: "PaymentSplitterUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.PaymentSplitterUpgradeable>;
    getContractAt(
      name: "IERC1822ProxiableUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC1822ProxiableUpgradeable>;
    getContractAt(
      name: "IERC2981Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC2981Upgradeable>;
    getContractAt(
      name: "IBeaconUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IBeaconUpgradeable>;
    getContractAt(
      name: "ERC1967UpgradeUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC1967UpgradeUpgradeable>;
    getContractAt(
      name: "Initializable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Initializable>;
    getContractAt(
      name: "UUPSUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.UUPSUpgradeable>;
    getContractAt(
      name: "ERC1155Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC1155Upgradeable>;
    getContractAt(
      name: "IERC1155MetadataURIUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC1155MetadataURIUpgradeable>;
    getContractAt(
      name: "IERC1155ReceiverUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC1155ReceiverUpgradeable>;
    getContractAt(
      name: "IERC1155Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC1155Upgradeable>;
    getContractAt(
      name: "ERC20Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC20Upgradeable>;
    getContractAt(
      name: "IERC20PermitUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20PermitUpgradeable>;
    getContractAt(
      name: "IERC20MetadataUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20MetadataUpgradeable>;
    getContractAt(
      name: "IERC20Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20Upgradeable>;
    getContractAt(
      name: "ContextUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ContextUpgradeable>;
    getContractAt(
      name: "ERC165Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC165Upgradeable>;
    getContractAt(
      name: "IERC165Upgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC165Upgradeable>;
    getContractAt(
      name: "VestingWallet",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.VestingWallet>;
    getContractAt(
      name: "IERC20Permit",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20Permit>;
    getContractAt(
      name: "IERC20",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20>;
    getContractAt(
      name: "PaymentBadgesAccessor",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.PaymentBadgesAccessor>;
    getContractAt(
      name: "FractionCostBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.FractionCostBadges>;
    getContractAt(
      name: "IFractionCostBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IFractionCostBadges>;
    getContractAt(
      name: "IListenerBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IListenerBadges>;
    getContractAt(
      name: "IPodcastBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IPodcastBadges>;
    getContractAt(
      name: "ListenerBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ListenerBadges>;
    getContractAt(
      name: "PodcastBadges",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.PodcastBadges>;
    getContractAt(
      name: "IMinter",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IMinter>;
    getContractAt(
      name: "Minter",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Minter>;
    getContractAt(
      name: "ContentPool",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ContentPool>;
    getContractAt(
      name: "ContentPool",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ContentPool>;
    getContractAt(
      name: "ContentPoolReview",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ContentPoolReview>;
    getContractAt(
      name: "IRewarder",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IRewarder>;
    getContractAt(
      name: "Referral",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Referral>;
    getContractAt(
      name: "Rewarder",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Rewarder>;
    getContractAt(
      name: "SybelInternalTokens",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SybelInternalTokens>;
    getContractAt(
      name: "SybelToken",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SybelToken>;
    getContractAt(
      name: "IPausable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IPausable>;
    getContractAt(
      name: "MintingAccessControlUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.MintingAccessControlUpgradeable>;
    getContractAt(
      name: "SybelAccessControlUpgradeable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SybelAccessControlUpgradeable>;
    getContractAt(
      name: "FoundationWallet",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.FoundationWallet>;
    getContractAt(
      name: "VestingWallets",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.VestingWallets>;

    // default types
    getContractFactory(
      name: string,
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<ethers.ContractFactory>;
    getContractFactory(
      abi: any[],
      bytecode: ethers.utils.BytesLike,
      signer?: ethers.Signer
    ): Promise<ethers.ContractFactory>;
    getContractAt(
      nameOrAbi: string | any[],
      address: string,
      signer?: ethers.Signer
    ): Promise<ethers.Contract>;
  }
}
