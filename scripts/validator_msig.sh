#!/bin/bash -eEx

set -o pipefail

# Copyright 2018-2020 TON DEV SOLUTIONS LTD.
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
#

if [ "$DEBUG" = "yes" ]; then
    set -x
fi

echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

STAKE="$1"

if [ -z "${STAKE}" ]; then
    echo "ERROR: STAKE (in tokens) is not specified"
    echo "Usage: $(basename "$0") <STAKE>"
    exit 1
fi

TONOS_CLI_SEND_ATTEMPTS="100"
MSIG_ADDR=$(cat "${KEYS_DIR}/${VALIDATOR_NAME}.addr")
echo "INFO: MSIG_ADDR = ${MSIG_ADDR}"
ELECTIONS_WORK_DIR="${KEYS_DIR}/elections"
mkdir -p "${ELECTIONS_WORK_DIR}"

NANOSTAKE=$("${UTILS_DIR}/tonos-cli" convert tokens "$STAKE")

"${TON_BUILD_DIR}/lite-client/lite-client" \
    -p "${KEYS_DIR}/liteserver.pub" \
    -a 127.0.0.1:3031 \
    -rc "getconfig 1" -rc "quit" \
    &>"${ELECTIONS_WORK_DIR}/elector-addr"

awk -v TON_BUILD_DIR="${TON_BUILD_DIR}" -v KEYS_DIR="${KEYS_DIR}" -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" '{
    if (substr($1, length($1)-13) == "ConfigParam(1)") {
        printf TON_BUILD_DIR "/lite-client/lite-client ";
        printf "-p " KEYS_DIR "/liteserver.pub -a 127.0.0.1:3031 ";
        printf "-rc \"runmethod -1:" substr($4, 15, 64) " ";
        print  "active_election_id\" -rc \"quit\" &> " ELECTIONS_WORK_DIR "/elector-state"
        printf "echo -1:" substr($4, 15, 64) " > " ELECTIONS_WORK_DIR "/elector-addr-base64"
    }
}' "${ELECTIONS_WORK_DIR}/elector-addr" >"${ELECTIONS_WORK_DIR}/elector-run"

bash "${ELECTIONS_WORK_DIR}/elector-run"

awk '{
    if ($1 == "result:") {
        print $3
    }
}' "${ELECTIONS_WORK_DIR}/elector-state" >"${ELECTIONS_WORK_DIR}/election-id"

election_id=$(cat "${ELECTIONS_WORK_DIR}/election-id")

if [ "$election_id" == "0" ]; then
    date +"INFO: %F %T No current elections"

    elector_addr=$(cat "${ELECTIONS_WORK_DIR}/elector-addr-base64")

    "${TON_BUILD_DIR}/lite-client/lite-client" \
        -p "${KEYS_DIR}/liteserver.pub" -a 127.0.0.1:3031 \
        -rc "runmethod ${elector_addr} compute_returned_stake 0x$(echo "${MSIG_ADDR}" | cut -d ':' -f 2)" \
        -rc "quit" &>"${ELECTIONS_WORK_DIR}/recover-state"

    awk '{
        if ($1 == "result:") {
            print $3
        }
    }' "${ELECTIONS_WORK_DIR}/recover-state" >"${ELECTIONS_WORK_DIR}/recover-amount"

    recover_amount=$(cat "${ELECTIONS_WORK_DIR}/recover-amount")

    if [ "$recover_amount" != "0" ]; then
        "${TON_BUILD_DIR}/crypto/fift" -I "${TON_SRC_DIR}/crypto/fift/lib:${TON_SRC_DIR}/crypto/smartcont" -s recover-stake.fif "${ELECTIONS_WORK_DIR}/recover-query.boc"

        recover_query_boc=$(base64 --wrap=0 "${ELECTIONS_WORK_DIR}/recover-query.boc")

        for i in $(seq ${TONOS_CLI_SEND_ATTEMPTS}); do
            echo "INFO: tonos-cli submitTransaction attempt #${i}..."
            if ! "${UTILS_DIR}/tonos-cli" call "${MSIG_ADDR}" submitTransaction \
                "{\"dest\":\"${elector_addr}\",\"value\":\"1000000000\",\"bounce\":true,\"allBalance\":false,\"payload\":\"${recover_query_boc}\"}" \
                --abi "${CONFIGS_DIR}/SafeMultisigWallet.abi.json" \
                --sign "${KEYS_DIR}/msig.keys.json"; then
                echo "INFO: tonos-cli submitTransaction attempt #${i}... FAIL"
            else
                echo "INFO: tonos-cli submitTransaction attempt #${i}... PASS"
                break
            fi
        done

        date +"INFO: %F %T Recover of $recover_amount GR requested"
    fi

    echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
    exit
fi

if [ -f "${ELECTIONS_WORK_DIR}/stop-election" ]; then
    echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
    exit
fi

if [ -f "${ELECTIONS_WORK_DIR}/active-election-id" ]; then
    active_election_id=$(cat "${ELECTIONS_WORK_DIR}/active-election-id")
    if [ "$active_election_id" = "$election_id" ]; then
        date +"INFO: %F %T Elections $election_id, already submitted"
        echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
        exit
    fi
fi

cp "${ELECTIONS_WORK_DIR}/election-id" "${ELECTIONS_WORK_DIR}/active-election-id"
date +"INFO: %F %T Elections $election_id"

"${TON_BUILD_DIR}/validator-engine-console/validator-engine-console" \
    -k "${KEYS_DIR}/client" \
    -p "${KEYS_DIR}/server.pub" \
    -a 127.0.0.1:3030 \
    -c "newkey" -c "quit" \
    &>"${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-key"

"${TON_BUILD_DIR}/validator-engine-console/validator-engine-console" \
    -k "${KEYS_DIR}/client" \
    -p "${KEYS_DIR}/server.pub" \
    -a 127.0.0.1:3030 \
    -c "newkey" -c "quit" \
    &>"${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-adnl-key"

"${TON_BUILD_DIR}/lite-client/lite-client" \
    -p "${KEYS_DIR}/liteserver.pub" \
    -a 127.0.0.1:3031 \
    -rc "getconfig 15" -rc "quit" \
    &>"${ELECTIONS_WORK_DIR}/elector-params"

awk -v validator="${VALIDATOR_NAME}" -v wallet_addr="$MSIG_ADDR" -v TON_BUILD_DIR="${TON_BUILD_DIR}" \
    -v KEYS_DIR="${KEYS_DIR}" -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" -v TON_SRC_DIR="${TON_SRC_DIR}" '{
    if (NR == 1) {
        election_start = $1 + 0
    } else if (($1 == "created") && ($2 == "new") && ($3 == "key")) {
        if (length(key) == 0) {
            key = $4
        } else {
            key_adnl = $4
        }
    } else if (substr($1, length($1)-14) == "ConfigParam(15)") {
        time = election_start + 1000;
        split($4, t, ":");
        time = time + t[2] + 0;
        split($5, t, ":");
        time = time + t[2] + 0;
        split($6, t, ":");
        time = time + t[2] + 0;
        split($7, t, ":");
        time = time + t[2] + 0;
        election_stop = time;
        printf TON_BUILD_DIR "/validator-engine-console/validator-engine-console ";
        printf "-k " KEYS_DIR "/client -p " KEYS_DIR "/server.pub -a 127.0.0.1:3030 ";
        printf "-c \"addpermkey " key " " election_start " " election_stop "\" ";
        printf "-c \"addtempkey " key " " key " " election_stop "\" ";
        printf "-c \"addadnl " key_adnl " 0\" ";
        printf "-c \"addvalidatoraddr " key " " key_adnl " " election_stop "\" ";
        print  "-c \"quit\"";
        printf TON_BUILD_DIR "/crypto/fift ";
        printf "-I " TON_SRC_DIR "/crypto/fift/lib:" TON_SRC_DIR "/crypto/smartcont ";
        printf "-s validator-elect-req.fif " wallet_addr;
        printf " " election_start " 2 " key_adnl " " ELECTIONS_WORK_DIR "/validator-to-sign.bin ";
        print  "> " ELECTIONS_WORK_DIR "/" validator "-request-dump"
    }
}' "${ELECTIONS_WORK_DIR}/election-id" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-key" \
    "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-adnl-key" "${ELECTIONS_WORK_DIR}/elector-params" >"${ELECTIONS_WORK_DIR}/elector-run1"

bash "${ELECTIONS_WORK_DIR}/elector-run1"

awk -v validator="${VALIDATOR_NAME}" -v TON_BUILD_DIR="${TON_BUILD_DIR}" -v KEYS_DIR="${KEYS_DIR}" -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" '{
    if (NR == 2) {
        request = $1
    } else if (($1 == "created") && ($2 == "new") && ($3 == "key")) {
        printf TON_BUILD_DIR "/validator-engine-console/validator-engine-console ";
        printf "-k " KEYS_DIR "/client -p " KEYS_DIR "/server.pub -a 127.0.0.1:3030 ";
        printf "-c \"exportpub " $4 "\" ";
        print  "-c \"sign " $4 " " request "\" &> " ELECTIONS_WORK_DIR "/" validator "-request-dump1"
   }
}' "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-request-dump" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-key" >"${ELECTIONS_WORK_DIR}/elector-run2"

bash "${ELECTIONS_WORK_DIR}/elector-run2"

awk -v validator="${VALIDATOR_NAME}" -v wallet_addr="$MSIG_ADDR" -v TON_BUILD_DIR="${TON_BUILD_DIR}" \
    -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" -v TON_SRC_DIR="${TON_SRC_DIR}" '{
    if (NR == 1) {
        election_start = $1 + 0
    } else if (($1 == "got") && ($2 == "public") && ($3 == "key:")) {
        key = $4
    } else if (($1 == "got") && ($2 == "signature")) {
        signature = $3
    } else if (($1 == "created") && ($2 == "new") && ($3 == "key")) {
        printf TON_BUILD_DIR "/crypto/fift ";
        printf "-I " TON_SRC_DIR "/crypto/fift/lib:" TON_SRC_DIR "/crypto/smartcont ";
        printf "-s validator-elect-signed.fif " wallet_addr " " election_start " 2 " $4;
        printf " " key " " signature " " ELECTIONS_WORK_DIR "/validator-query.boc ";
        print  "> " ELECTIONS_WORK_DIR "/" validator "-request-dump2"
    }
}' "${ELECTIONS_WORK_DIR}/election-id" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-request-dump1" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-adnl-key" >"${ELECTIONS_WORK_DIR}/elector-run3"

bash "${ELECTIONS_WORK_DIR}/elector-run3"

#send validator query to elector contract using multisig
validator_query_boc=$(base64 --wrap=0 "${ELECTIONS_WORK_DIR}/validator-query.boc")
elector_addr=$(cat "${ELECTIONS_WORK_DIR}/elector-addr-base64")

for i in $(seq ${TONOS_CLI_SEND_ATTEMPTS}); do
    echo "INFO: tonos-cli submitTransaction attempt #${i}..."
    if ! "${UTILS_DIR}/tonos-cli" call "${MSIG_ADDR}" submitTransaction \
        "{\"dest\":\"${elector_addr}\",\"value\":\"${NANOSTAKE}\",\"bounce\":true,\"allBalance\":false,\"payload\":\"${validator_query_boc}\"}" \
        --abi "${CONFIGS_DIR}/SafeMultisigWallet.abi.json" \
        --sign "${KEYS_DIR}/msig.keys.json"; then
        echo "INFO: tonos-cli submitTransaction attempt #${i}... FAIL"
    else
        echo "INFO: tonos-cli submitTransaction attempt #${i}... PASS"
        break
    fi
done

date +"INFO: %F %T prepared for elections"

echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
