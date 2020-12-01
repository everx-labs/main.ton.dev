#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

echo "INFO: start TON node..."
echo "INFO: log file = ${TON_WORK_DIR}/node.log"

# shellcheck disable=SC2086
"${TON_BUILD_DIR}/validator-engine/validator-engine" ${ENGINE_ADDITIONAL_PARAMS} \
    -C "${TON_WORK_DIR}/etc/ton-global.config.json" --db "${TON_WORK_DIR}/db" > "${TON_WORK_DIR}/node.log" 2>&1 &

echo "INFO: start TON node... DONE"
