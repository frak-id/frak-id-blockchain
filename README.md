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

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any
contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Setup EC2 for testing

````shell
sudo yum update -y
sudo yum install docker -y
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo yum install git
mkdir sybel
cd sybel/
git clone https://**PersonalGitAccessToken**@github.com/sybel-app/frak-id-blockchain.git
cd frak-id-blockchain/
git status
git pull
npm i
nohup sh tools/run-all-nohup.sh
````