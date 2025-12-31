# blockmaze-testnet-script

This repository provides ubuntu 22.04 and 24.04 script for running a node on blockmaze devnet:

System Requirements:

- Operating System: Ubuntu 22.04 or 24.04
- Memory: At least 16GB RAM
- Storage: Minimum 20GB available disk space
- Network: Stable internet connection
- CPU: 4core

Clone this repo using:
git clone '<https://github.com/blockmaze/blockmaze-testnet-node-script.git>'

Setup the node:
open a terminal window and run the following command:

```bash
./blockmaze_ubuntu_node.sh
```

once it finishes, start the node service with the following command:

```bash
sudo systemctl start blockmazechain.service
```

check the node logs with the following command:

```bash
journalctl -u blockmazechain.service -f
```
