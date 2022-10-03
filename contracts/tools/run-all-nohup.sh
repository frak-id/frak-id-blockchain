#!/bin/bash

# Assert we are on the root folder
if [ ! -d "contracts" ]; then 
	echo "error: script needs to be run from project root './tools/run-all-nohup.sh'"
	exit 1
fi

# Exec the run all script with nohup
nohup sh tools/run-all.sh > security-analysis.log 2>&1 &