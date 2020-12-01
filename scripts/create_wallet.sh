#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

cd "${KEYS_DIR}"
"${TON_BUILD_DIR}/crypto/fift" -I "${TON_SRC_DIR}/crypto/fift/lib:${TON_SRC_DIR}/crypto/smartcont" -s new-wallet.fif -1 \
    "${HOSTNAME}" > "${KEYS_DIR}/${HOSTNAME}-dump"
grep "Non-bounceable address" "${KEYS_DIR}/${HOSTNAME}-dump" | awk '{print $5}' > "${KEYS_DIR}/${HOSTNAME}-wallet"
# shellcheck disable=SC2086
echo "INFO: validator wallet = $(cat ${KEYS_DIR}/${HOSTNAME}-wallet)"
