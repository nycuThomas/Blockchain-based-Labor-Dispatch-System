#!/usr/bin/env bash

generateArtifacts() {
  printHeadline "Generating basic configs" "U1F913"

  printItalics "Generating crypto material for Orderer" "U1F512"
  certsGenerate "$FABLO_NETWORK_ROOT/fabric-config" "crypto-config-orderer.yaml" "peerOrganizations/orderer.example.com" "$FABLO_NETWORK_ROOT/fabric-config/crypto-config/"

  printItalics "Generating crypto material for Org1" "U1F512"
  certsGenerate "$FABLO_NETWORK_ROOT/fabric-config" "crypto-config-org1.yaml" "peerOrganizations/org1.example.com" "$FABLO_NETWORK_ROOT/fabric-config/crypto-config/"

  printItalics "Generating crypto material for Org2" "U1F512"
  certsGenerate "$FABLO_NETWORK_ROOT/fabric-config" "crypto-config-org2.yaml" "peerOrganizations/org2.example.com" "$FABLO_NETWORK_ROOT/fabric-config/crypto-config/"

  printItalics "Generating crypto material for Org3" "U1F512"
  certsGenerate "$FABLO_NETWORK_ROOT/fabric-config" "crypto-config-org3.yaml" "peerOrganizations/org3.example.com" "$FABLO_NETWORK_ROOT/fabric-config/crypto-config/"

  printItalics "Generating genesis block for group group1" "U1F3E0"
  genesisBlockCreate "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config" "Group1Genesis"

  # Create directory for chaincode packages to avoid permission errors on linux
  mkdir -p "$FABLO_NETWORK_ROOT/fabric-config/chaincode-packages"
}

startNetwork() {
  printHeadline "Starting network" "U1F680"
  (cd "$FABLO_NETWORK_ROOT"/fabric-docker && docker-compose up -d)
  sleep 4
}

generateChannelsArtifacts() {
  printHeadline "Generating config for 'main-channel'" "U1F913"
  createChannelTx "main-channel" "$FABLO_NETWORK_ROOT/fabric-config" "MainChannel" "$FABLO_NETWORK_ROOT/fabric-config/config"
  printHeadline "Generating config for 'acc-channel'" "U1F913"
  createChannelTx "acc-channel" "$FABLO_NETWORK_ROOT/fabric-config" "AccChannel" "$FABLO_NETWORK_ROOT/fabric-config/config"
}

installChannels() {
  printHeadline "Creating 'main-channel' on Org1/peer0" "U1F63B"
  docker exec -i cli.org1.example.com bash -c "source scripts/channel_fns.sh; createChannelAndJoinTls 'main-channel' 'Org1MSP' 'peer0.org1.example.com:7041' 'crypto/users/Admin@org1.example.com/msp' 'crypto/users/Admin@org1.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"

  printItalics "Joining 'main-channel' on  Org2/peer0" "U1F638"
  docker exec -i cli.org2.example.com bash -c "source scripts/channel_fns.sh; fetchChannelAndJoinTls 'main-channel' 'Org2MSP' 'peer0.org2.example.com:7061' 'crypto/users/Admin@org2.example.com/msp' 'crypto/users/Admin@org2.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"
  printItalics "Joining 'main-channel' on  Org3/peer0" "U1F638"
  docker exec -i cli.org3.example.com bash -c "source scripts/channel_fns.sh; fetchChannelAndJoinTls 'main-channel' 'Org3MSP' 'peer0.org3.example.com:7081' 'crypto/users/Admin@org3.example.com/msp' 'crypto/users/Admin@org3.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"
  printHeadline "Creating 'acc-channel' on Org1/peer0" "U1F63B"
  docker exec -i cli.org1.example.com bash -c "source scripts/channel_fns.sh; createChannelAndJoinTls 'acc-channel' 'Org1MSP' 'peer0.org1.example.com:7041' 'crypto/users/Admin@org1.example.com/msp' 'crypto/users/Admin@org1.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"

  printItalics "Joining 'acc-channel' on  Org2/peer0" "U1F638"
  docker exec -i cli.org2.example.com bash -c "source scripts/channel_fns.sh; fetchChannelAndJoinTls 'acc-channel' 'Org2MSP' 'peer0.org2.example.com:7061' 'crypto/users/Admin@org2.example.com/msp' 'crypto/users/Admin@org2.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"
  printItalics "Joining 'acc-channel' on  Org3/peer0" "U1F638"
  docker exec -i cli.org3.example.com bash -c "source scripts/channel_fns.sh; fetchChannelAndJoinTls 'acc-channel' 'Org3MSP' 'peer0.org3.example.com:7081' 'crypto/users/Admin@org3.example.com/msp' 'crypto/users/Admin@org3.example.com/tls' 'crypto-orderer/tlsca.orderer.example.com-cert.pem' 'orderer0.group1.orderer.example.com:7030';"
}

installChaincodes() {
  if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node")" ]; then
    local version="0.0.1"
    printHeadline "Packaging chaincode 'issuerReviewer'" "U1F60E"
    chaincodeBuild "issuerReviewer" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node" "12"
    chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "node" printHeadline "Installing 'issuerReviewer' for Org1" "U1F60E"
    chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'issuerReviewer' for Org2" "U1F60E"
    chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'issuerReviewer' for Org3" "U1F60E"
    chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printItalics "Committing chaincode 'issuerReviewer' on channel 'main-channel' as 'Org1'" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""
  else
    echo "Warning! Skipping chaincode 'issuerReviewer' installation. Chaincode directory is empty."
    echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node'"
  fi
  if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node")" ]; then
    local version="0.0.1"
    printHeadline "Packaging chaincode 'certManager'" "U1F60E"
    chaincodeBuild "certManager" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node" "12"
    chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "node" printHeadline "Installing 'certManager' for Org1" "U1F60E"
    chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'certManager' for Org2" "U1F60E"
    chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'certManager' for Org3" "U1F60E"
    chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printItalics "Committing chaincode 'certManager' on channel 'main-channel' as 'Org1'" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""
  else
    echo "Warning! Skipping chaincode 'certManager' installation. Chaincode directory is empty."
    echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node'"
  fi
  if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go")" ]; then
    local version="0.0.1"
    printHeadline "Packaging chaincode 'agrmtManager'" "U1F60E"
    chaincodeBuild "agrmtManager" "golang" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go" "12"
    chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "golang" printHeadline "Installing 'agrmtManager' for Org1" "U1F60E"
    chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'agrmtManager' for Org2" "U1F60E"
    chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'agrmtManager' for Org3" "U1F60E"
    chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printItalics "Committing chaincode 'agrmtManager' on channel 'main-channel' as 'Org1'" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""
  else
    echo "Warning! Skipping chaincode 'agrmtManager' installation. Chaincode directory is empty."
    echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go'"
  fi
  if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node")" ]; then
    local version="0.0.1"
    printHeadline "Packaging chaincode 'accessControl'" "U1F60E"
    chaincodeBuild "accessControl" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node" "12"
    chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "node" printHeadline "Installing 'accessControl' for Org1" "U1F60E"
    chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'accessControl' for Org2" "U1F60E"
    chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printHeadline "Installing 'accessControl' for Org3" "U1F60E"
    chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
    printItalics "Committing chaincode 'accessControl' on channel 'acc-channel' as 'Org1'" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""
  else
    echo "Warning! Skipping chaincode 'accessControl' installation. Chaincode directory is empty."
    echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node'"
  fi

}

installChaincode() {
  local chaincodeName="$1"
  if [ -z "$chaincodeName" ]; then
    echo "Error: chaincode name is not provided"
    exit 1
  fi

  local version="$2"
  if [ -z "$version" ]; then
    echo "Error: chaincode version is not provided"
    exit 1
  fi

  if [ "$chaincodeName" = "issuerReviewer" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node")" ]; then
      printHeadline "Packaging chaincode 'issuerReviewer'" "U1F60E"
      chaincodeBuild "issuerReviewer" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "node" printHeadline "Installing 'issuerReviewer' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'issuerReviewer' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'issuerReviewer' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'issuerReviewer' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'issuerReviewer' install. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node'"
    fi
  fi
  if [ "$chaincodeName" = "certManager" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node")" ]; then
      printHeadline "Packaging chaincode 'certManager'" "U1F60E"
      chaincodeBuild "certManager" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "node" printHeadline "Installing 'certManager' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'certManager' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'certManager' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'certManager' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'certManager' install. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node'"
    fi
  fi
  if [ "$chaincodeName" = "agrmtManager" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go")" ]; then
      printHeadline "Packaging chaincode 'agrmtManager'" "U1F60E"
      chaincodeBuild "agrmtManager" "golang" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "golang" printHeadline "Installing 'agrmtManager' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'agrmtManager' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'agrmtManager' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'agrmtManager' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'agrmtManager' install. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go'"
    fi
  fi
  if [ "$chaincodeName" = "accessControl" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node")" ]; then
      printHeadline "Packaging chaincode 'accessControl'" "U1F60E"
      chaincodeBuild "accessControl" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "node" printHeadline "Installing 'accessControl' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'accessControl' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'accessControl' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'accessControl' on channel 'acc-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'accessControl' install. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node'"
    fi
  fi
}

runDevModeChaincode() {
  local chaincodeName=$1
  if [ -z "$chaincodeName" ]; then
    echo "Error: chaincode name is not provided"
    exit 1
  fi

  if [ "$chaincodeName" = "issuerReviewer" ]; then
    local version="0.0.1"
    printHeadline "Approving 'issuerReviewer' for Org1 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'issuerReviewer' for Org2 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "issuerReviewer" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'issuerReviewer' for Org3 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "issuerReviewer" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printItalics "Committing chaincode 'issuerReviewer' on channel 'main-channel' as 'Org1' (dev mode)" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "" ""

  fi
  if [ "$chaincodeName" = "certManager" ]; then
    local version="0.0.1"
    printHeadline "Approving 'certManager' for Org1 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'certManager' for Org2 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "certManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'certManager' for Org3 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "certManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printItalics "Committing chaincode 'certManager' on channel 'main-channel' as 'Org1' (dev mode)" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "" ""

  fi
  if [ "$chaincodeName" = "agrmtManager" ]; then
    local version="0.0.1"
    printHeadline "Approving 'agrmtManager' for Org1 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'agrmtManager' for Org2 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "agrmtManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'agrmtManager' for Org3 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "agrmtManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printItalics "Committing chaincode 'agrmtManager' on channel 'main-channel' as 'Org1' (dev mode)" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "" ""

  fi
  if [ "$chaincodeName" = "accessControl" ]; then
    local version="0.0.1"
    printHeadline "Approving 'accessControl' for Org1 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'accessControl' for Org2 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "acc-channel" "accessControl" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printHeadline "Approving 'accessControl' for Org3 (dev mode)" "U1F60E"
    chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "acc-channel" "accessControl" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" ""
    printItalics "Committing chaincode 'accessControl' on channel 'acc-channel' as 'Org1' (dev mode)" "U1F618"
    chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "0.0.1" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "" ""

  fi
}

upgradeChaincode() {
  local chaincodeName="$1"
  if [ -z "$chaincodeName" ]; then
    echo "Error: chaincode name is not provided"
    exit 1
  fi

  local version="$2"
  if [ -z "$version" ]; then
    echo "Error: chaincode version is not provided"
    exit 1
  fi

  if [ "$chaincodeName" = "issuerReviewer" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node")" ]; then
      printHeadline "Packaging chaincode 'issuerReviewer'" "U1F60E"
      chaincodeBuild "issuerReviewer" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "node" printHeadline "Installing 'issuerReviewer' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'issuerReviewer' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'issuerReviewer' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "issuerReviewer" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'issuerReviewer' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "issuerReviewer" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'issuerReviewer' upgrade. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-issuerReviewer-node'"
    fi
  fi
  if [ "$chaincodeName" = "certManager" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node")" ]; then
      printHeadline "Packaging chaincode 'certManager'" "U1F60E"
      chaincodeBuild "certManager" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "node" printHeadline "Installing 'certManager' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'certManager' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'certManager' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "certManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'certManager' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "certManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'certManager' upgrade. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-certManager-node'"
    fi
  fi
  if [ "$chaincodeName" = "agrmtManager" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go")" ]; then
      printHeadline "Packaging chaincode 'agrmtManager'" "U1F60E"
      chaincodeBuild "agrmtManager" "golang" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "golang" printHeadline "Installing 'agrmtManager' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'agrmtManager' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'agrmtManager' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "agrmtManager" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'agrmtManager' on channel 'main-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "main-channel" "agrmtManager" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'agrmtManager' upgrade. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-agrmtManager-go'"
    fi
  fi
  if [ "$chaincodeName" = "accessControl" ]; then
    if [ -n "$(ls "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node")" ]; then
      printHeadline "Packaging chaincode 'accessControl'" "U1F60E"
      chaincodeBuild "accessControl" "node" "$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node" "12"
      chaincodePackage "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "node" printHeadline "Installing 'accessControl' for Org1" "U1F60E"
      chaincodeInstall "cli.org1.example.com" "peer0.org1.example.com:7041" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'accessControl' for Org2" "U1F60E"
      chaincodeInstall "cli.org2.example.com" "peer0.org2.example.com:7061" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org2.example.com" "peer0.org2.example.com:7061" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printHeadline "Installing 'accessControl' for Org3" "U1F60E"
      chaincodeInstall "cli.org3.example.com" "peer0.org3.example.com:7081" "accessControl" "$version" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
      chaincodeApprove "cli.org3.example.com" "peer0.org3.example.com:7081" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" ""
      printItalics "Committing chaincode 'accessControl' on channel 'acc-channel' as 'Org1'" "U1F618"
      chaincodeCommit "cli.org1.example.com" "peer0.org1.example.com:7041" "acc-channel" "accessControl" "$version" "orderer0.group1.orderer.example.com:7030" "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" "false" "crypto-orderer/tlsca.orderer.example.com-cert.pem" "peer0.org1.example.com:7041,peer0.org2.example.com:7061,peer0.org3.example.com:7081" "crypto-peer/peer0.org1.example.com/tls/ca.crt,crypto-peer/peer0.org2.example.com/tls/ca.crt,crypto-peer/peer0.org3.example.com/tls/ca.crt" ""

    else
      echo "Warning! Skipping chaincode 'accessControl' upgrade. Chaincode directory is empty."
      echo "Looked in dir: '$CHAINCODES_BASE_DIR/./chaincodes/chaincode-accessControl-node'"
    fi
  fi
}

notifyOrgsAboutChannels() {
  printHeadline "Creating new channel config blocks" "U1F537"
  createNewChannelUpdateTx "main-channel" "Org1MSP" "MainChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"
  createNewChannelUpdateTx "main-channel" "Org2MSP" "MainChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"
  createNewChannelUpdateTx "main-channel" "Org3MSP" "MainChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"
  createNewChannelUpdateTx "acc-channel" "Org1MSP" "AccChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"
  createNewChannelUpdateTx "acc-channel" "Org2MSP" "AccChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"
  createNewChannelUpdateTx "acc-channel" "Org3MSP" "AccChannel" "$FABLO_NETWORK_ROOT/fabric-config" "$FABLO_NETWORK_ROOT/fabric-config/config"

  printHeadline "Notyfing orgs about channels" "U1F4E2"
  notifyOrgAboutNewChannelTls "main-channel" "Org1MSP" "cli.org1.example.com" "peer0.org1.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
  notifyOrgAboutNewChannelTls "main-channel" "Org2MSP" "cli.org2.example.com" "peer0.org2.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
  notifyOrgAboutNewChannelTls "main-channel" "Org3MSP" "cli.org3.example.com" "peer0.org3.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
  notifyOrgAboutNewChannelTls "acc-channel" "Org1MSP" "cli.org1.example.com" "peer0.org1.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
  notifyOrgAboutNewChannelTls "acc-channel" "Org2MSP" "cli.org2.example.com" "peer0.org2.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"
  notifyOrgAboutNewChannelTls "acc-channel" "Org3MSP" "cli.org3.example.com" "peer0.org3.example.com" "orderer0.group1.orderer.example.com:7030" "crypto-orderer/tlsca.orderer.example.com-cert.pem"

  printHeadline "Deleting new channel config blocks" "U1F52A"
  deleteNewChannelUpdateTx "main-channel" "Org1MSP" "cli.org1.example.com"
  deleteNewChannelUpdateTx "main-channel" "Org2MSP" "cli.org2.example.com"
  deleteNewChannelUpdateTx "main-channel" "Org3MSP" "cli.org3.example.com"
  deleteNewChannelUpdateTx "acc-channel" "Org1MSP" "cli.org1.example.com"
  deleteNewChannelUpdateTx "acc-channel" "Org2MSP" "cli.org2.example.com"
  deleteNewChannelUpdateTx "acc-channel" "Org3MSP" "cli.org3.example.com"
}

printStartSuccessInfo() {
  printHeadline "Done! Enjoy your fresh network" "U1F984"
}

stopNetwork() {
  printHeadline "Stopping network" "U1F68F"
  (cd "$FABLO_NETWORK_ROOT"/fabric-docker && docker-compose stop)
  sleep 4
}

networkDown() {
  printHeadline "Destroying network" "U1F916"
  (cd "$FABLO_NETWORK_ROOT"/fabric-docker && docker-compose down)

  printf "\nRemoving chaincode containers & images... \U1F5D1 \n"
  for container in $(docker ps -a | grep "dev-peer0.org1.example.com-issuerReviewer" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org1.example.com-issuerReviewer*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org2.example.com-issuerReviewer" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org2.example.com-issuerReviewer*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org3.example.com-issuerReviewer" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org3.example.com-issuerReviewer*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org1.example.com-certManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org1.example.com-certManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org2.example.com-certManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org2.example.com-certManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org3.example.com-certManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org3.example.com-certManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org1.example.com-agrmtManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org1.example.com-agrmtManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org2.example.com-agrmtManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org2.example.com-agrmtManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org3.example.com-agrmtManager" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org3.example.com-agrmtManager*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org1.example.com-accessControl" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org1.example.com-accessControl*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org2.example.com-accessControl" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org2.example.com-accessControl*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done
  for container in $(docker ps -a | grep "dev-peer0.org3.example.com-accessControl" | awk '{print $1}'); do
    echo "Removing container $container..."
    docker rm -f "$container" || echo "docker rm of $container failed. Check if all fabric dockers properly was deleted"
  done
  for image in $(docker images "dev-peer0.org3.example.com-accessControl*" -q); do
    echo "Removing image $image..."
    docker rmi "$image" || echo "docker rmi of $image failed. Check if all fabric dockers properly was deleted"
  done

  printf "\nRemoving generated configs... \U1F5D1 \n"
  rm -rf "$FABLO_NETWORK_ROOT/fabric-config/config"
  rm -rf "$FABLO_NETWORK_ROOT/fabric-config/crypto-config"
  rm -rf "$FABLO_NETWORK_ROOT/fabric-config/chaincode-packages"

  printHeadline "Done! Network was purged" "U1F5D1"
}
