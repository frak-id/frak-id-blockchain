#!/bin/bash

# Assert we are in the right folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/echidna/echidna.sh'"
	exit 1
fi

docker run --rm -v `pwd`:/src  -it --workdir=/src ghcr.io/crytic/echidna/echidna bash -c 'solc-select install 0.8.17 && solc-select use 0.8.17 && 
echidna-test tools/echidna/tokens/TestSybelTokenTransferable.sol --contract TestSybelTokenTransferable --config tools/echidna/tokens/echidna_config.yaml'
#docker run --rm -v "$PWD":/contracts -it --workdir=/contracts trailofbits/eth-security-toolbox -c 'solc-select install 0.8.17 && solc-select use 0.8.17 && 
#echidna-test --version && 
#echidna-test tools/echidna/utils/SybelMathEchidnaTest.sol'

# echidna-test tools/echidna/tokens/SybelToken.sol