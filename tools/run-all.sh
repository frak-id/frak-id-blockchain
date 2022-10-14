#!/bin/bash

# Assert we are on the root folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/run-all.sh'"
	exit 1
fi

# Perform slithen flatten and slither analysis
echo "=============================="
echo "=== Starting security scan ==="
echo "=============================="

#echo ""
#echo "!!==========================!!"
#echo "!!= Slither flatten        =!!"
#echo "\\/==========================\\/"
#./tools/slither/flatten.sh
#echo "/\\==========================/\\"
#echo "!!= Slither flatten        =!!"
#echo "!!==========================!!"

#echo "!!==========================!!"
#echo "!!= Slither Analysis       =!!"
#echo "\\/==========================\\/"
./tools/slither/slither.sh > tools/slither-output.log
#echo "/\\==========================/\\"
#echo "!!= Slither Analysis       =!!"
#echo "!!==========================!!"

# Perform Mythril run
echo "!!==========================!!"
echo "!!= Mythril                =!!"
echo "\\/==========================\\/"
./tools/mythril/mythril.sh > tools/mythril-output.log
echo "/\\==========================/\\"
echo "!!= Mythril                =!!"
echo "!!==========================!!"

# Perform Manticore run
#echo "!!==========================!!"
#echo "!!= Manticore              =!!"
#echo "\\/==========================\\/"
#./tools/manticore/manticore.sh > tools/manticore-output.log
#echo "/\\==========================/\\"
#echo "!!= Manticore              =!!"
#echo "!!==========================!!"

echo ""
echo "=============================="
echo "=== Ended security scan    ==="
echo "=============================="