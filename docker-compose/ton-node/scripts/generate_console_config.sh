#!/bin/bash -eEx

if [ "$DEBUG" = "yes" ]; then
    set -x
fi

export TON_NODE_ROOT_DIR="/ton-node"
export TON_NODE_CONFIGS_DIR="${TON_NODE_ROOT_DIR}/configs"
export TON_NODE_TOOLS_DIR="${TON_NODE_ROOT_DIR}/tools"
export TON_NODE_LOGS_DIR="${TON_NODE_ROOT_DIR}/logs"
export RNODE_CONSOLE_SERVER_PORT="3031"

HOSTNAME=$(hostname -f)
TMP_DIR="/tmp/$(basename "$0" .sh)_$$"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

"${TON_NODE_TOOLS_DIR}/keygen" >"${TON_NODE_CONFIGS_DIR}/${HOSTNAME}_console_client_keys.json"
cat "${TON_NODE_CONFIGS_DIR}/${HOSTNAME}_console_client_keys.json"
jq -c .public "${TON_NODE_CONFIGS_DIR}/${HOSTNAME}_console_client_keys.json" >"${TON_NODE_CONFIGS_DIR}/console_client_public.json"

jq ".control_server_port = ${RNODE_CONSOLE_SERVER_PORT}" "${TON_NODE_CONFIGS_DIR}/default_config.json" >"${TMP_DIR}/default_config.json.tmp"
cp "${TMP_DIR}/default_config.json.tmp" "${TON_NODE_CONFIGS_DIR}/default_config.json"

# Generate initial config.json
#cd "${TON_NODE_ROOT_DIR}" && "${TON_NODE_ROOT_DIR}/ton_node_no_kafka_compression" --configs "${TON_NODE_CONFIGS_DIR}" --ckey "$(cat "${TON_NODE_CONFIGS_DIR}/console_client_public.json")" &
cd "${TON_NODE_ROOT_DIR}" && "${TON_NODE_ROOT_DIR}/ton_node_no_kafka" --configs "${TON_NODE_CONFIGS_DIR}" --ckey "$(cat "${TON_NODE_CONFIGS_DIR}/console_client_public.json")" &

sleep 10

if [ ! -f "${TON_NODE_CONFIGS_DIR}/config.json" ]; then
    echo "ERROR: ${TON_NODE_CONFIGS_DIR}/config.json does not exist"
    exit 1
fi

cat "${TON_NODE_CONFIGS_DIR}/config.json"

if [ ! -f "${TON_NODE_CONFIGS_DIR}/console_config.json" ]; then
    echo "ERROR: ${TON_NODE_CONFIGS_DIR}/console_config.json does not exist"
    exit 1
fi

cat "${TON_NODE_CONFIGS_DIR}/console_config.json"

jq ".client_key = $(jq .private "${TON_NODE_CONFIGS_DIR}/${HOSTNAME}_console_client_keys.json")" "${TON_NODE_CONFIGS_DIR}/console_config.json" >"${TMP_DIR}/console_config.json.tmp"
jq ".config = $(cat "${TMP_DIR}/console_config.json.tmp")" "${TON_NODE_CONFIGS_DIR}/console_template.json" >"${TON_NODE_CONFIGS_DIR}/console.json"
rm -f "${TON_NODE_CONFIGS_DIR}/console_config.json"

rm -rf "${TMP_DIR}"
