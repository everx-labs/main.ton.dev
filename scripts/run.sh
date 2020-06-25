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
# under the License.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

echo "INFO: start TON node..."
echo "INFO: log file = ${TON_WORK_DIR}/node.log"

# shellcheck disable=SC2086
"${TON_BUILD_DIR}/validator-engine/validator-engine" ${ENGINE_ADDITIONAL_PARAMS} \
    -C "${TON_WORK_DIR}/etc/ton-global.config.json" --db "${TON_WORK_DIR}/db" > "${TON_WORK_DIR}/node.log" 2>&1 &

echo "INFO: start TON node... DONE"
