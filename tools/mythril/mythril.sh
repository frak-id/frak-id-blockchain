#!/bin/bash

# Assert we are in the right folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/mythril/mythril.sh'"
	exit 1
fi

# Run mythril analyse on the given contract
function analyse_contract {
	docker run --rm -v `pwd`:/src  --workdir=/src mythril/myth -v 4 analyze $1 --solc-json tools/mythril/remapping.json --max-depth 50
}

echo "<----- Checking SybelMath.sol ----->"
analyse_contract contracts/utils/SybelMath.sol

echo ""
echo "<----- Checking MultiVestingWallets.sol ----->"
analyse_contract contracts/wallets/MultiVestingWallets.sol

echo ""
echo "<----- Checking VestingWalletFactory.sol ----->"
analyse_contract contracts/wallets/VestingWalletFactory.sol

echo ""
echo "<----- Checking SybelTokenL2.sol ----->"
analyse_contract contracts/tokens/SybelTokenL2.sol
