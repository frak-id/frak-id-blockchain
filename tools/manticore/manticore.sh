#!/bin/bash

# Assert we are on the root folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/manticore/manticore.sh'"
	exit 1
fi

# Remove previous manticore run
rm -rf mcore_*/

# Run manticore
docker run --rm -v "$PWD":/src --ulimit stack=100000000:100000000 --workdir=/src trailofbits/manticore bash -c 'pip3 install solc-select && 
solc-select install 0.8.17 && solc-select use 0.8.17 && 
manticore contracts/utils/FrakMath.sol --contract=SybelMath --config=tools/manticore/manticore.yaml &&
manticore contracts/utils/FrakRoles.sol --contract=SybelRoles --config=tools/manticore/manticore.yaml'

# Test of the sybel token broken, caused by https://github.com/trailofbits/manticore/issues/2455
# manticore contracts/tokens/SybelToken.sol --contract=SybelToken --config=tools/manticore/manticore.yaml --solc-remaps @openzeppelin=node_modules/@openzeppelin'