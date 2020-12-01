#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

mkdir -p "${KEYS_DIR}"

TONOS_CLI_OUTPUT=$("${UTILS_DIR}/tonos-cli" genaddr "${CONFIGS_DIR}/SafeMultisigWallet.tvc" \
    "${CONFIGS_DIR}/SafeMultisigWallet.abi.json" --genkey "${KEYS_DIR}/msig.keys.json" --wc -1)
RAW_ADDRESS=$(echo "${TONOS_CLI_OUTPUT}" | grep "Raw address" | cut -d ' ' -f 3)
SEED_PHRASE=$(echo "${TONOS_CLI_OUTPUT}" | grep "Seed phrase" | sed -e 's/Seed phrase: //' | tr -d '"')
echo "${RAW_ADDRESS}" >"${KEYS_DIR}/${VALIDATOR_NAME}.addr"
echo "INFO: Raw address = ${RAW_ADDRESS}"
echo "INFO: Seed phrase = ${SEED_PHRASE}"
