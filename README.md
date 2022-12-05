# <img src="logo.jpeg" alt="frak-logo" height="150"/>

[![Project license](https://badgen.net/github/sybel-app/frak-id-blockchain)](https://github.com/sybel-app/frak-id-blockchain/LICENSE.txt)

[![solidity - v0.8.117](https://img.shields.io/badge/solidity-v0.8.17-2ea44f?logo=solidity)](https://github.com/sybel-app/frak-id-blockchain)

[![Test smart contracts](https://github.com/sybel-app/frak-id-blockchain/actions/workflows/test.yml/badge.svg)](https://github.com/sybel-app/frak-id-blockchain/actions/workflows/test.yml)

[![SafetinErc20](https://badgen.net/badge/Safetin%20ecosystem/passed/green?icon=https://uploads-ssl.webflow.com/624b2fb0a98b08011e0bf1d0/624c870d20ffb8fcf547507c_icon-safetin.svg)](https://www.safetin.com/audit/frak)
[![SafetinEcosystem](https://badgen.net/badge/Safetin%20erc20/passed/green?icon=https://uploads-ssl.webflow.com/624b2fb0a98b08011e0bf1d0/624c870d20ffb8fcf547507c_icon-safetin.svg)](https://www.safetin.com/audit/frak-2)
[![MythXBadge](https://badgen.net/https/api.mythx.io/v1/projects/df0aab13-6b4e-4e67-ab53-d4472414264a/badge/data?cache=300&icon=https://raw.githubusercontent.com/ConsenSys/mythx-github-badge/main/logo_white.svg)](https://docs.mythx.io/dashboard/github-badges)

# Frak.id

The Frak Ecosystem is build to align interests of Creators and their Community in order to reinvent the IP monetization
market. Creators mint their Work as a NFT and can fractionalize it in different rarity tokens to offer their community
the opportunity to buy some shares, in exchange for profits, rewards or even governance rights.
Then, when a User interact (listen, watch, read...) with content, on the platform of their choice, Creators earn
tokens (TSE) that they share with Users. Several interactions can make Users reach the next level to get special
NFT.Creators mint their Work as a NFT and fractionalize it to offer their community the opportunity to buy some shares,
in exchange for profits, rewards or even governance rights (micro DAO).
Creators’ and Users’ TSE earnings are stored in the in-app custodial Wallet created for them. Custodial Wallets have a
built-in Swap function.

## Our Vision

Our vision is to give Creators the rightful place they deserve in society. The value has to be shared equally between
those who create, those who fund and those who consume content. By empowering all these people to govern and to be
rewarded for the value they create, whether that be through work, investment or engagement, the Frak ecosystem believes
that Web3 is the ideal way to make that happens.

```ml
minter
├─ Minter — "Mint new content, mint fraktions of content and increase fraktions supply"
├─ badges
│  ├─ FractionCostBadges — "Small contract that store the cost badges of each fraktions"
reward
├─ Rewarder — "Reward the user content consumption, from contentIds and CCU's"
├─ badges
│  ├─ ContentBadges — "Small contract storing the badges for each content's"
│  ├─ ListenerBadges — "Small contract storing the badges for each listener's"
├─ pool
│  ├─ ContentPool — "Pool that split reward gain for each content between each investor's"
│  ├─ ReferralPool — "Pool that split reward gain by each listener to each one of his referrer"
tokens
├─ FraktionTransferCallback — "Callback interface for the transfer of content fraktions"
├─ SybelInternalTokens — "ERC1155 storing all of our fraktions"
├─ SybelTokenL1 — "FrkToken on the ETH chain (for bridge purpose only)"
├─ SybelTokenL2 — "FrkToken on the Polygon chain"
wallets
├─ MultiVestingWallets — "Contract that handle the vestings of multiple user's"
├─ VestingWalletFactory — "Helping us with the creation of vestings following some defined criteria (initial drop, cliff etc)"
utils
├─ SybelRoles — "All the roles we use in our contracts"
├─ SybelMath — "Some math utils, to create fraktionId, or extract contentId from fraktionId."
├─ SybelAccessControlUpgradeable — "Base access control contract used by every contract"
├─ MintingAccessControlUpgradeable — "Reviewed access control contract, with more options for the minting part (so for token's and minter)"
├─ PushPullReward — "Abtract contract that implement basic Push/Pull reward (we store reward amount, then the user withdraw it), helping us gain some gas"
```

## Installation

To install and build with [**Hardhat**](https://github.com/nomiclabs/hardhat) :

```sh
# Install
git clone https://github.com/sybel-app/frak-id-blockchain.git
cd frak-id-blockchain/
npm i
# Build
npm run build
# Test
npm run test
```

To install with [**Foundry**](https://github.com/gakonst/foundry):

```sh
# Install
git clone https://github.com/sybel-app/frak-id-blockchain.git
cd frak-id-blockchain/
# Build
forge build
```

## Keep in touch

[![Home page](https://badgen.net/badge/icon/website?icon=https://frak.id/images/logos/frak_logo_01.svg&label)](https://frak.id/)

[![FAQ page](https://badgen.net/badge/icon/white%20paper?icon=https://frak.id/images/logos/frak_logo_01.svg&label)](https://help.frak.id/)

[![Medium Badge](https://badgen.net/badge/icon/medium?icon=medium&label)](https://medium.com/frak-defi)

[![Twitter Badge](https://badgen.net/badge/icon/twitter?icon=twitter&label)](https://twitter.com/frak_defi)

