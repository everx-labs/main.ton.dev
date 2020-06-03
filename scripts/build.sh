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

if [ "${INSTALL_DEPENDENCIES}" = "yes" ]; then
    if ! sudo -V >/dev/null ; then
        echo "Looks like sudo is not installed. You need to install it to proceed with dependencies installation"
        exit 0
    fi
    echo "INFO: install dependencies..."
    sudo apt update && sudo apt -y install \
        build-essential \
        git \
        cargo \
        ccache \
        cmake \
        gawk \
        gcc \
        gperf \
        g++ \
        libgflags-dev \
        libmicrohttpd-dev \
        libreadline-dev \
        libssl-dev \
        libz-dev \
        ninja-build \
        pkg-config \
        zlib1g-dev
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    #shellcheck source=$HOME/.cargo/env
    . "$HOME/.cargo/env"
    rustup update
    echo "INFO: install dependencies... DONE"
fi

rm -rf "${TON_SRC_DIR}"

echo "INFO: clone ${TON_GITHUB_REPO} (${TON_STABLE_GITHUB_COMMIT_ID})..."
git clone --recursive "${TON_GITHUB_REPO}" "${TON_SRC_DIR}"
cd "${TON_SRC_DIR}" && git checkout "${TON_STABLE_GITHUB_COMMIT_ID}"
echo "INFO: clone ${TON_GITHUB_REPO} (${TON_STABLE_GITHUB_COMMIT_ID})... DONE"

# TODO remove after fix upstream
cd "${TON_SRC_DIR}"
git apply "${NET_TON_DEV_SRC_TOP_DIR}/patches/0001-Fix-for-neighbours-unreliability.patch"

echo "INFO: build a node..."
mkdir -p "${TON_BUILD_DIR}"
cd "${TON_BUILD_DIR}"
#cmake -DCMAKE_BUILD_TYPE=Release ..
#cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
#cmake --build .
#cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DPORTABLE=ON
cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON
ninja
echo "INFO: build a node... DONE"

echo "INFO: build utils (convert_address)..."
cd "${NET_TON_DEV_SRC_TOP_DIR}/utils/convert_address"
cargo update
cargo build --release
cp "${NET_TON_DEV_SRC_TOP_DIR}/utils/convert_address/target/release/convert_address" "${UTILS_DIR}/"
echo "INFO: build utils (convert_address)... DONE"

echo "INFO: build utils (tonos-cli)..."
rm -rf "${TONOS_CLI_SRC_DIR}"
git clone https://github.com/tonlabs/tonos-cli.git "${TONOS_CLI_SRC_DIR}"
cd "${TONOS_CLI_SRC_DIR}"
cargo update
cargo build --release
cp "${TONOS_CLI_SRC_DIR}/target/release/tonos-cli" "${UTILS_DIR}/"
echo "INFO: build utils (tonos-cli)... DONE"

rm -rf "${NET_TON_DEV_SRC_TOP_DIR}/ton-labs-contracts"
git clone https://github.com/tonlabs/ton-labs-contracts.git "${NET_TON_DEV_SRC_TOP_DIR}/ton-labs-contracts"
rm -f "${CONFIGS_DIR}/SafeMultisigWallet.tvc"
rm -f "${CONFIGS_DIR}/SafeMultisigWallet.abi.json"
cp "${NET_TON_DEV_SRC_TOP_DIR}/ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.tvc" "${CONFIGS_DIR}"
cp "${NET_TON_DEV_SRC_TOP_DIR}/ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json" "${CONFIGS_DIR}"
