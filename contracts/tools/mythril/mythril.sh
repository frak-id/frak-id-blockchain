#!/bin/bash

# Assert we are in the right folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/mythril/mythril.sh'"
	exit 1
fi

echo "<----- Checking SybelMath.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/utils/SybelMath.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking SybelToken.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/tokens/SybelToken.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking VestingWallets.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/wallets/VestingWallets.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking SybelInternalTokens.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/tokens/SybelInternalTokens.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking Minter.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/minter/Minter.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking Rewarder.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/reward/Rewarder.sol --solc-json tools/mythril/remapping.json --max-depth 50

echo ""
echo "<----- Checking Referral.sol ----->"
docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze contracts/reward/Referral.sol --solc-json tools/mythril/remapping.json --max-depth 50
