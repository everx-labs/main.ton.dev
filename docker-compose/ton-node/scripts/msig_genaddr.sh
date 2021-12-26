#!/bin/bash -eE

export TON_NODE_ROOT_DIR="/ton-node"
export TON_NODE_CONFIGS_DIR="${TON_NODE_ROOT_DIR}/configs"
export TON_NODE_KEYS_DIR="${TON_NODE_CONFIGS_DIR}/keys"
export TON_NODE_TOOLS_DIR="${TON_NODE_ROOT_DIR}/tools"
export TON_NODE_LOGS_DIR="${TON_NODE_ROOT_DIR}/logs"

mkdir -p "${TON_NODE_KEYS_DIR}"

apt update >/dev/null 2>&1 && apt install -y wget >/dev/null 2>&1

if [ ! -f "${TON_NODE_CONFIGS_DIR}/SafeMultisigWallet.abi.json" ]; then
    cd ${TON_NODE_CONFIGS_DIR} && wget https://raw.githubusercontent.com/tonlabs/ton-labs-contracts/master/solidity/safemultisig/SafeMultisigWallet.abi.json
fi

if [ ! -f "${TON_NODE_CONFIGS_DIR}/SafeMultisigWallet.tvc" ]; then
    cd ${TON_NODE_CONFIGS_DIR} && wget https://github.com/tonlabs/ton-labs-contracts/raw/master/solidity/safemultisig/SafeMultisigWallet.tvc
fi

cd ${TON_NODE_TOOLS_DIR}
TONOS_CLI_OUTPUT=$("${TON_NODE_TOOLS_DIR}/tonos-cli" genaddr "${TON_NODE_CONFIGS_DIR}/SafeMultisigWallet.tvc" \
    "${TON_NODE_CONFIGS_DIR}/SafeMultisigWallet.abi.json" --genkey "${TON_NODE_KEYS_DIR}/msig.keys.json" --wc -1)
RAW_ADDRESS=$(echo "${TONOS_CLI_OUTPUT}" | grep "Raw address" | cut -d ' ' -f 3)
SEED_PHRASE=$(echo "${TONOS_CLI_OUTPUT}" | grep "Seed phrase" | sed -e 's/Seed phrase: //' | tr -d '"')
echo "${RAW_ADDRESS}" >"${TON_NODE_CONFIGS_DIR}/${VALIDATOR_NAME}.addr"
echo "INFO: Raw address = ${RAW_ADDRESS}"
echo "INFO: Seed phrase = ${SEED_PHRASE}"
