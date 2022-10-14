#!/bin/bash

# Assert we are in the right folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/mythril/mythril.sh'"
	exit 1
fi

# Run the mythx analysis
mythx --api-key ***Api Key*** analyze --remap-import "@openzeppelin/=$(pwd)/node_modules/@openzeppelin/" --async --mode deep ../../contracts/wallets/VestingWallets.sol