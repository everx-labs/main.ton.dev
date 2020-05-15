# README

This HOWTO contains instructions on how to build and configure a validator node in TON blockchain. The instructions and scripts below were verified on Ubuntu 18.04.
# Getting Started

## 1. System Requirements
| Configuration | CPU (cores) | RAM (GiB) | Storage (GiB) | Network (Gbit/s)|
|---|:---|:---|:---|:---|
| Minimal |8|16|1000|1|
| Recommended |16|32|1000|1| 
SSD disks are recommended for /var/ton-work/db storage.
## 2. Prerequisites
### 2.1 Set the Environment
Adjust (if needed) `main.ton.dev/scripts/env.sh`
    
    $ cd main.ton.dev/scripts/
    $ . ./env.sh 
### 2.2 Build Node
Build a node:

    $ ./build.sh
### 2.3 Setup Node
Initialize a node:

    $ ./setup.sh
### 2.4 Prepare Multisignature Wallet
**Note**: All manual calls of the TONOS-CLI utility should be performed from the `scripts` folder.

Multisignature wallet (or just wallet) is used in validator script to send election requests to the Elector smart contract.

Let `N` be the total number of wallet custodians and `K` the number of minimal confirmations required to execute a wallet transaction.

1. Read [TONOS-CLI documentation](https://docs.ton.dev/86757ecb2/v/0/p/94921e-running-tonos-cli-with-tails-os-and-working-with-multisignature-wallet) (*Deploying Multisignature Wallet to TON blockchain*) and generate seed phrases and public keys for `N - 1`  custodians.
2. Generate wallet address and `Nth` custodian key:
```
    $ ./msig_genaddr.sh
```
Script creates 2 files: `$(hostname -s).addr` and `msig.keys.json` in `~/ton-keys/` folder. 
Use public key from `msig.keys.json` as `Nth` custodian public key when you will deploy the wallet.

## 3. Run Validator Node
Do this step when the network is launched.
Run the node:

    $ ./run.sh
  
Wait until the node is synced with the masterchain. Depending on network throughput this step may take significant time (up to several hours).

You may use the following script to check if the node is synced:

    $ ./check_node_sync_status.sh

Script output example:
```
connecting to [127.0.0.1:3030]
local key: FB0A67F8992DB0EF51860D45E89951275A4D6EB6A381BBF99023292982F97247
remote key: 2AD4363BE4BCCEFEF667CB919B199C4710278B8E2B0D972E18D1E5A17B62A99D
conn ready
unixtime            1588443685
masterchainblock            (-1,8000000000000000,989):85316E413BD4FFBE76AF7BCDC2A75C27B2BA3AE45381D0CE7B5684949447DF07:6D975F062203F2A2F913FC528387036F47B27AB156B76E4127C186E32A6ED9C3
masterchainblocktime            1588443683
gcmasterchainblock            (-1,8000000000000000,0):3D009F42614CBA3537A41596BFD6E598756C83332668990C914D67A3B137D37D:40D1F2B2588A6A00D8AB05C8C1E944E42B172B5C111867B70DBC41009EE10C55
keymasterchainblock            (-1,8000000000000000,669):712CBAF305CB9AF1CD3745FDDB8E184796D8A21E7C559A42EB6B68D8B2F2FF89:3B03B9075B20BD1E6111492C41756F337FF649C6C89B9F87D446FAC47DCFD2BB
knownkeymasterchainblock            (-1,8000000000000000,669):712CBAF305CB9AF1CD3745FDDB8E184796D8A21E7C559A42EB6B68D8B2F2FF89:3B03B9075B20BD1E6111492C41756F337FF649C6C89B9F87D446FAC47DCFD2BB
rotatemasterchainblock            (-1,8000000000000000,918):4DD1DF6361F4B406DCC948B99E0D1ADD6988AC8F824F2E1B263CFED2AD46742E:12A8599C16C5EF1B09713F7EC91E2F765E97545F046FE6871DCD0C82E0377036
stateserializermasterchainseqno            984
shardclientmasterchainseqno            988
INFO: TIME_DIFF = -2
```
If the `TIME_DIFF` parameter equals a few seconds, synchronization is complete.

### 3.1 Initialize multisignature wallet

**Note**: All manual calls of the TONOS-CLI utility should be performed from the `scripts` folder.


Gather all custodians' public keys and deploy wallet using [TONOS-CLI](https://docs.ton.dev/86757ecb2/v/0/p/94921e-running-tonos-cli-with-tails-os-and-working-with-multisignature-wallet) (lookup Deploying Multisignature Wallet to TON blockchain in the document above). Use `K` value as `reqConfirms` deploy parameter.
Make sure that the wallet was deployed at the address saved in `$(hostname -s).addr` file.


### 3.2 Run Validator script

Specify `<STAKE>` argument in tokens. This amount of tokens will be sent by wallet to Elector smart contract in every validation cycle.

Run the validator script (periodically, e.g. each 60 min.):

    $ ./validator_msig.sh <STAKE> >> ./validator_msig.log 2>&1

cron example (run each hour):

    @hourly        script --return --quiet --append --command "/main.ton.dev/scripts/00_validator_msig.sh ${STAKE} 2>&1" /var/ton-work/validator_msig.log


### How validator script works

Script runs every minute.

1. Makes an initial check for masterchain.
2. Checks startup time.
3. Gets address of elector contract and reads `election_id` from elector contract.
4. If `election_id` == 0 (that means no validator elections at the moment):
    1. script requests size of validator stake that can be returned from elector. (by running Elector's `compute_returned_stake` get-method). Returned value will not be 0 if validator won previous elections and was a validator;
    2. if this value != 0, script submits new transaction from wallet to Elector contract with 1 token and `recover-stake` payload;
    3. if request to wallet succeeds, script extracts `transactionId` and prints it in terminal and then exits. Other wallet custodians should confirm transaction using this Id. 
5. If `election_id` != 0 (that means it's time to participate in elections):
    1. checks if `stop-election` file exists then exits;
    2. checks if file `active-election-id` exists, then reads `active_election_id` from it and compares it to `election_id`. If they are equal then exits (it means that validator has already sent its stake to Elector in current elections);
    3. calls `validator-engine-console` to generate new validator key and adnl address;
    4. reads config param 15 to get elections timeouts;
    5. runs `validator-elect-req.fif` fift script to generate unsigned validator election request;
    6. calls `validator-engine-console` to sign election request with newly generated validator keypair;
    7. submits new transaction from wallet to Elector contract with `$stake` amount of tokens and `process_new_stake` payload;
    8. if request to wallet succeeds, script extracts `transactionId` and prints it in terminal;
    9. wallet custodians should confirm transaction using this Id. When wallet accumulates the required number of confirmations, it sends validator election request to Elector.



