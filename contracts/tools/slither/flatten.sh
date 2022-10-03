#!/bin/bash

# Assert we are on the root folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/slither/flatten.sh'"
	exit 1
fi

# Flatten only the contract we will use for echnide
docker run --rm -v "$PWD":/src --workdir=/src trailofbits/eth-security-toolbox -c 'solc-select install 0.8.17 && solc-select use 0.8.17 && 
rm -r crytic-export/flattening/ && 
slither-flat . --strategy LocalImport --solc-remaps @openzeppelin=node_modules/@openzeppelin --convert-external'