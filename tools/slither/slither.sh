#!/bin/bash

# Assert we are on the root folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/slither/slither.sh'"
	exit 1
fi

docker run --rm -v "$(pwd)":/src --workdir=/src trailofbits/eth-security-toolbox -c 'solc-select install 0.8.17 && solc-select use 0.8.17 && 
slither . --solc-args="--optimize" --solc-remaps @openzeppelin=node_modules/@openzeppelin'