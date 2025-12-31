#!/bin/bash

# Check if the script is run as root
#if [ "$(id -u)" != "0" ]; then
#  echo "This script must be run as root or with sudo." 1>&2
#  exit 1
#fi
current_path=$(pwd)
bash  $current_path/install-go.sh 

source $HOME/.bashrc
ulimit -n 16384

# ============================================
# Define persistent peers as array
# Add your node IDs and IPs here in format: node-id@ip:26656
# ============================================
PEERS=(
  "node-id-1@192.168.1.1:26656"
  "node-id-2@192.168.1.2:26656"
  "node-id-3@192.168.1.3:26656"
)
# Join array elements with comma separator
PERSISTENT_PEERS=$(IFS=,; echo "${PEERS[*]}")
# ============================================

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
# Determine the path of cosmovisor
COSMOVISOR_PATH=$(which cosmovisor)
echo "Cosmovisor is installed at: $COSMOVISOR_PATH"

# Get OS and version
OS=$(awk -F '=' '/^NAME/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')
VERSION=$(awk -F '=' '/^VERSION_ID/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')



# Define the binary and installation paths
BINARY="blockmazed"
INSTALL_PATH="/usr/local/bin/"                   #AWS
#  INSTALL_PATH="/root/go/bin/"                  #Huawei

# Check if the OS is Ubuntu and the version is either 22.04 or 24.04
if [ "$OS" == "Ubuntu" ] && [ "$VERSION" == "22.04" -o "$VERSION" == "24.04" ]; then
  # Copy and set executable permissions
  current_path=$(pwd)
  
  # Update package lists and install necessary packages
  sudo  apt-get update
  sudo apt-get install -y build-essential jq wget unzip
  
  # Check if the installation path exists
  if [ -d "$INSTALL_PATH" ]; then

# --- Binary Download Logic ---
# Detect Ubuntu version for choosing the matching prebuilt binary
# UBUNTU_VERSION=$(lsb_release -rs)
# Set binary download URL (update this if your release URL pattern is different)
BINARY_URL="https://github.com/NodeNavigator/blockmaze-testnet-node-script/releases/download/ubuntu${VERSION}/${BINARY}"
echo $BINARY_URL

# Download and install the node binary into the chosen install path
echo "Downloading binary for Ubuntu $UBUNTU_VERSION: $BINARY_URL"
curl -L "$BINARY_URL" -o "/tmp/${BINARY}"
chmod +x "/tmp/${BINARY}"
sudo cp "/tmp/${BINARY}" "$INSTALL_PATH"
echo "Binary moved to ${INSTALL_PATH}${BINARY}"
sudo chmod +x "${INSTALL_PATH}${BINARY}"
  # sudo  cp "$current_path/ubuntu${VERSION}build/$BINARY" "$INSTALL_PATH" && sudo chmod +x "${INSTALL_PATH}${BINARY}"
    echo "$BINARY installed or updated successfully!"
  else
    echo "Installation path $INSTALL_PATH does not exist. Please create it."
    exit 1
  fi
else
  echo "Please check the OS version support; at this time, only Ubuntu 20.04 and 22.04 are supported."
  exit 1
fi


#==========================================================================================================================================
echo "============================================================================================================"
echo "Enter the Name for the node:"
echo "============================================================================================================"
read -r MONIKER
KEYS="mykey"
CHAINID="${CHAIN_ID:-blockmaze_6163-1}"
KEYRING="os"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"

# Set dedicated home directory for the blockmazed instance
 HOMEDIR="/data/.tmp-blockmazed"


# Check if the service is running
if systemctl is-active --quiet blockmazechain.service; then
    echo "Service is running. Stopping and removing it."
    
    sudo systemctl stop blockmazechain.service
    sudo rm -rf "$HOMEDIR"
    sudo rm -rf /etc/systemd/system/blockmazechain.service
else
    echo "Service is not running. Skipping removal steps."
fi

# Path variables
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
CLIENT=$HOMEDIR/config/client.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error
set -e

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
	printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
	echo "Overwrite the existing configuration and start a new local node? [y/n]"
	read -r overwrite
else
	overwrite="Y"
fi

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	file_path="/etc/systemd/system/blockmazechain.service"

# Check if the file exists
if [ -e "$file_path" ]; then
sudo systemctl stop blockmazechain.service
echo "The file $file_path exists."
fi
	sudo rm -rf "$HOMEDIR"

	# Set client config
  $BINARY config set client chain-id "$CHAINID" --home "$HOMEDIR"
	$BINARY config set client keyring-backend "$KEYRING" --home "$HOMEDIR"
	
  echo "===========================Copy these keys with mnemonics and save it in safe place ==================================="
	$BINARY keys add $KEYS --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
	echo "========================================================================================================================"
	echo "========================================================================================================================"
	$BINARY init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"
 

	#changes status in app,config files
    sed -i 's/timeout_commit = "3s"/timeout_commit = "6s"/g' "$CONFIG"
    #sed -i 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
    sed -i 's/pruning-keep-recent = "0"/pruning-keep-recent = "100000"/g' "$APP_TOML"
    sed -i 's/pruning-interval = "0"/pruning-interval = "100"/g' "$APP_TOML"
    sed -i 's/seeds = ""/seeds = ""/g' "$CONFIG"
    sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
    sed -i 's/experimental_websocket_write_buffer_size = 200/experimental_websocket_write_buffer_size = 600/' "$CONFIG"
    sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
    sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
    sed -i 's/minimum-gas-prices = "0bmz"/minimum-gas-prices = "0.0000015bmz"/g' "$APP_TOML"
    sed -i 's/enable = false/enable = true/g' "$APP_TOML"
    sed -i 's/swagger = false/swagger = true/g' "$APP_TOML"
    sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' "$APP_TOML"
    sed -i 's/enable-unsafe-cors = false/enable-unsafe-cors = true/g' "$APP_TOML"
    sed -i '/\[rosetta\]/,/^\[.*\]/ s/enable = true/enable = false/' "$APP_TOML"
    sed -i 's/localhost/0.0.0.0/g' "$APP_TOML"
    sed -i 's/localhost/0.0.0.0/g' "$CONFIG"
    sed -i 's/:26660/0.0.0.0:26660/g' "$CONFIG"
    sed -i 's/localhost/0.0.0.0/g' "$CLIENT"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$APP_TOML"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CONFIG"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CLIENT"
    sed -i 's/\[\]/["*"]/g' "$CONFIG"
	  sed -i 's/\["\*",\]/["*"]/g' "$CONFIG"
  
	# remove the genesis file from binary
	 rm -rf $HOMEDIR/config/genesis.json

	# paste the genesis file
	 cp $current_path/genesis.json $HOMEDIR/config

	# Run this to ensure everything worked and that the genesis file is setup correctly
	$BINARY validate-genesis --home "$HOMEDIR"

	echo "export DAEMON_NAME=blockmazed" >> ~/.profile
    echo "export DAEMON_HOME="$HOMEDIR"" >> ~/.profile
    source ~/.profile
    echo $DAEMON_HOME
    echo $DAEMON_NAME

	cosmovisor init "${INSTALL_PATH}${BINARY}"
	
  	# Set persistent peers from PEERS array (comma-separated)
	if [ -n "$PERSISTENT_PEERS" ]; then
		# Use pipe (|) as delimiter to avoid issues with @ and : in peer addresses
		sed -i "s|persistent_peers = \"\"|persistent_peers = \"$PERSISTENT_PEERS\"|g" "$CONFIG"
	fi
	TENDERMINTPUBKEY=$($BINARY tendermint show-validator --home $HOMEDIR | grep "key" | cut -c12-)
	NodeId=$($BINARY tendermint show-node-id --home $HOMEDIR --keyring-backend $KEYRING)
	BECH32ADDRESS=$($BINARY keys show ${KEYS} --home $HOMEDIR --keyring-backend $KEYRING| grep "address" | cut -c12-)

	echo "========================================================================================================================"
	echo "tendermint Key==== "$TENDERMINTPUBKEY
	echo "BECH32Address==== "$BECH32ADDRESS
	echo "NodeId ===" $NodeId
	echo "========================================================================================================================"

    # Don't enable Rosetta API by default
		grep -q -F '[rosetta]' "$APP_TOML" && sed -i '/\[rosetta\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable memiavl by default
		grep -q -F '[memiavl]' "$APP_TOML" && sed -i '/\[memiavl\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable versionDB by default
		grep -q -F '[versiondb]' "$APP_TOML" && sed -i '/\[versiondb\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
fi

#========================================================================================================================================================
sudo su -c  "echo '[Unit]
Description=blockmaze Node
Wants=network-online.target
After=network-online.target
[Service]
User=$(whoami)
Group=$(whoami)
Type=simple
ExecStart=$COSMOVISOR_PATH run start --home $DAEMON_HOME --chain-id "$CHAINID" --json-rpc.api eth,txpool,personal,net,debug,web3
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=blockmazed"
Environment="DAEMON_HOME="$HOMEDIR""
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=false"
[Install]
WantedBy=multi-user.target'> /etc/systemd/system/blockmazechain.service"

sudo systemctl daemon-reload
sudo systemctl enable blockmazechain.service
# blockmazed tendermint unsafe-reset-all --home $HOMEDIR
# sudo systemctl start blockmazechain.service
