#!/bin/bash -eEx

BEGIN_TIME_STAMP=$(date +%s)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

if ! command -v jq >/dev/null; then
    echo "ERROR: please install jq"
    exit 1
fi

rm -rf "${DOCKER_COMPOSE_DIR}/ton-node/build/ton-node"
cd "${DOCKER_COMPOSE_DIR}/ton-node/build" && git clone --recursive "${TON_NODE_GITHUB_REPO}" ton-node
cd "${DOCKER_COMPOSE_DIR}/ton-node/build/ton-node" && git checkout "${TON_NODE_GITHUB_COMMIT_ID}"

rm -rf "${DOCKER_COMPOSE_DIR}/ton-node/build/ton-labs-node-tools"
cd "${DOCKER_COMPOSE_DIR}/ton-node/build" && git clone --recursive "${TON_NODE_TOOLS_GITHUB_REPO}"
cd "${DOCKER_COMPOSE_DIR}/ton-node/build/ton-labs-node-tools" && git checkout "${TON_NODE_TOOLS_GITHUB_COMMIT_ID}"

rm -rf "${DOCKER_COMPOSE_DIR}/ton-node/build/tonos-cli"
cd "${DOCKER_COMPOSE_DIR}/ton-node/build" && git clone --recursive "${TONOS_CLI_GITHUB_REPO}"
cd "${DOCKER_COMPOSE_DIR}/ton-node/build/tonos-cli" && git checkout "${TONOS_CLI_GITHUB_COMMIT_ID}"

NODE_MEM_LIMIT_DYNAMIC="$((($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1000 / 1000 - 1)))G"
NODE_MEM_LIMIT="${NODE_MEM_LIMIT:-${NODE_MEM_LIMIT_DYNAMIC}}"
sed -i "s|MEM_LIMIT=.*|MEM_LIMIT=${NODE_MEM_LIMIT}|g" "${DOCKER_COMPOSE_DIR}/ton-node/.env"

cd "${DOCKER_COMPOSE_DIR}/ton-node/configs/" && jq '.restore_db = true' ./config.json >./config.json.tmp
cd "${DOCKER_COMPOSE_DIR}/ton-node/configs/" && mv -f ./config.json.tmp ./config.json

cd "${DOCKER_COMPOSE_DIR}/ton-node/" && docker-compose build --no-cache
cd "${DOCKER_COMPOSE_DIR}/ton-node/" && docker-compose down
cd "${DOCKER_COMPOSE_DIR}/ton-node/" && docker-compose up -d

END_TIME_STAMP=$(date +%s)
SCRIPT_DURATION=$((END_TIME_STAMP - BEGIN_TIME_STAMP))

echo "INFO: script duration = ${SCRIPT_DURATION} sec."
