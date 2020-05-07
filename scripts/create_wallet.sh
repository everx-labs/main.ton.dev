#!/bin/bash -eE

# Copyright 2020 TON DEV SOLUTIONS LTD.
#
# Licensed under the SOFTWARE EVALUATION License (the "License"); you may not use
# this file except in compliance with the License.  You may obtain a copy of the
# License at:
#
# https://www.ton.dev/licenses
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific TON DEV software governing permissions and limitations
# under the License

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

cd "${KEYS_DIR}"
"${TON_BUILD_DIR}/crypto/fift" -I "${TON_SRC_DIR}/crypto/fift/lib:${TON_SRC_DIR}/crypto/smartcont" -s new-wallet.fif -1 \
    "${HOSTNAME}" > "${KEYS_DIR}/${HOSTNAME}-dump"
grep "Non-bounceable address" "${KEYS_DIR}/${HOSTNAME}-dump" | awk '{print $5}' > "${KEYS_DIR}/${HOSTNAME}-wallet"
# shellcheck disable=SC2086
echo "INFO: validator wallet = $(cat ${KEYS_DIR}/${HOSTNAME}-wallet)"
