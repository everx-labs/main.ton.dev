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

if [ "$DEBUG" = "yes" ]
then
    set -x
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# Verified on Ubuntu 18.04
export INSTALL_DEPENDENCIES="yes"
#NET_TON_DEV_SRC_TOP_DIR=$(git rev-parse --show-toplevel)
NET_TON_DEV_SRC_TOP_DIR=$(cd "${SCRIPT_DIR}/../" && pwd -P)
export NET_TON_DEV_SRC_TOP_DIR
export TON_GITHUB_REPO="https://github.com/tonlabs/ton-1.git"
export TON_STABLE_GITHUB_COMMIT_ID="069b7f28227dc0ed9040a9da6b4e008e4a178315"
export TON_SRC_DIR="${NET_TON_DEV_SRC_TOP_DIR}/ton"
export TON_BUILD_DIR="${TON_SRC_DIR}/build"
export TONOS_CLI_SRC_DIR="${NET_TON_DEV_SRC_TOP_DIR}/tonos-cli"
export TON_WORK_DIR="/var/ton-work"
export UTILS_DIR="${TON_BUILD_DIR}/utils"
export KEYS_DIR="$HOME/ton-keys"
export CONFIGS_DIR="${NET_TON_DEV_SRC_TOP_DIR}/configs"
export ADNL_PORT="30310"
HOSTNAME=$(hostname -s)
export HOSTNAME
export VALIDATOR_NAME="$HOSTNAME"
export PATH="${UTILS_DIR}:$PATH"
export LITESERVER_IP="127.0.0.1"
export LITESERVER_PORT="3031"
export ENGINE_ADDITIONAL_PARAMS=""
