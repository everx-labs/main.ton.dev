#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

"${TON_BUILD_DIR}/lite-client/lite-client" --verbosity 9 -p "${KEYS_DIR}/liteserver.pub" -a 127.0.0.1:3031 -rc "sendfile ${KEYS_DIR}/${HOSTNAME}-query.boc" -rc "quit"
