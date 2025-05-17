#!/usr/bin/env bash

# The code from this file was called after Fablo generated Hyperledger Fabric configuration
echo "Executing post-generate hook"

perl -i -pe 's/MaxMessageCount: 10/MaxMessageCount: 1000/g' "./fablo-target/fabric-config/configtx.yaml"
