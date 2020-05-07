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

TIME_DIFF=0

"${TON_BUILD_DIR}/validator-engine-console/validator-engine-console" \
    -a 127.0.0.1:3030 \
    -k "${KEYS_DIR}/client" \
    -p "${KEYS_DIR}/server.pub" \
    -c "getstats" -c "quit"

for i in $("${TON_BUILD_DIR}/validator-engine-console/validator-engine-console" \
    -a 127.0.0.1:3030 \
    -k "${KEYS_DIR}/client" \
    -p "${KEYS_DIR}/server.pub" \
    -c "getstats" -c "quit" 2>&1 | grep time | awk '{print $2}'); do
    TIME_DIFF=$((i - TIME_DIFF))
done

echo "INFO: TIME_DIFF = ${TIME_DIFF}"
