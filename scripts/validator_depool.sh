#!/bin/bash -eE

set -o pipefail

if [ "$DEBUG" = "yes" ]; then
    set -x
fi

echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

CRYPTO_LIBS="${TON_SRC_DIR}/crypto/fift/lib:${TON_SRC_DIR}/crypto/smartcont"
MAX_FACTOR=${MAX_FACTOR:-3}
TONOS_CLI_SEND_ATTEMPTS="10"
ELECTOR_ADDR="-1:3333333333333333333333333333333333333333333333333333333333333333"
MSIG_ADDR=$(cat "${KEYS_DIR}/${VALIDATOR_NAME}.addr")
DEPOOL_ADDR=$(cat "${KEYS_DIR}/depool.addr")
echo "INFO: MSIG_ADDR = ${MSIG_ADDR}"
ELECTIONS_WORK_DIR="${KEYS_DIR}/elections"
mkdir -p "${ELECTIONS_WORK_DIR}"

ACTIVE_ELECTION_ID_HEX=$("${UTILS_DIR}/tonos-cli" runget ${ELECTOR_ADDR} active_election_id 2>&1 | grep "Result:" | awk -F'"' '{print $2}')
ACTIVE_ELECTION_ID=$(printf "%d" "${ACTIVE_ELECTION_ID_HEX}")
echo "INFO: ACTIVE_ELECTION_ID = ${ACTIVE_ELECTION_ID}"

echo "${ACTIVE_ELECTION_ID}" >"${ELECTIONS_WORK_DIR}/election-id"

if [ "${ACTIVE_ELECTION_ID}" = "0" ]; then
    date +"INFO: %F %T No current elections"
    echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
    exit 0
fi

if [ -f "${ELECTIONS_WORK_DIR}/stop-election" ]; then
    echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
    exit 0
fi

if [ -f "${ELECTIONS_WORK_DIR}/active-election-id-submitted" ]; then
    ACTIVE_ELECTION_ID_SUBMITTED=$(cat "${ELECTIONS_WORK_DIR}/active-election-id-submitted")
    if [ "${ACTIVE_ELECTION_ID_SUBMITTED}" = "${ACTIVE_ELECTION_ID}" ]; then
        date +"INFO: %F %T Elections ${ACTIVE_ELECTION_ID} already submitted"
        echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
        exit 0
    fi
fi

date +"INFO: %F %T Elections ${ACTIVE_ELECTION_ID}"

"${UTILS_DIR}/tonos-cli" depool --addr "${DEPOOL_ADDR}" events >"${ELECTIONS_WORK_DIR}/events.txt" 2>&1

set +eE
ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT=$(grep "^{" "${ELECTIONS_WORK_DIR}/events.txt" | grep electionId |
    jq ".electionId" | head -1 | tr -d '"' | xargs printf "%d\n")
echo "INFO: ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT = ${ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT}"

if [ "${ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT}" = "${ACTIVE_ELECTION_ID}" ]; then
    PROXY_ADDR_FROM_DEPOOL_EVENT=$(grep "^{" "${ELECTIONS_WORK_DIR}/events.txt" | grep electionId |
        jq ".proxy" | head -1 | tr -d '"')
    echo "INFO: PROXY_ADDR_FROM_DEPOOL_EVENT = ${PROXY_ADDR_FROM_DEPOOL_EVENT}"
    if [ -z "${PROXY_ADDR_FROM_DEPOOL_EVENT}" ]; then
        echo "ERROR: unable to detect PROXY_ADDR_FROM_DEPOOL_EVENT"
        exit 1
    fi
else
    echo "ERROR: ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT (${ACTIVE_ELECTION_ID_FROM_DEPOOL_EVENT}) does not match to ACTIVE_ELECTION_ID (${ACTIVE_ELECTION_ID})"
    echo "Verify '${UTILS_DIR}/tonos-cli depool --addr ${DEPOOL_ADDR} events' output"
    exit 1
fi
set -eE

ELECTIONS_ARTEFACTS_CREATED="0"
if [ -f "${ELECTIONS_WORK_DIR}/election-artefacts-created" ] &&
    [ "${ACTIVE_ELECTION_ID}" = "$(cat "${ELECTIONS_WORK_DIR}/election-artefacts-created")" ]; then
    ELECTIONS_ARTEFACTS_CREATED="1"
fi

if [ "${ELECTIONS_ARTEFACTS_CREATED}" = "0" ]; then
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

    awk -v validator="${VALIDATOR_NAME}" -v wallet_addr="${PROXY_ADDR_FROM_DEPOOL_EVENT}" -v TON_BUILD_DIR="${TON_BUILD_DIR}" \
        -v KEYS_DIR="${KEYS_DIR}" -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" -v CRYPTO_LIBS="${CRYPTO_LIBS}" \
        -v MAX_FACTOR="${MAX_FACTOR}" '{
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
            printf "-I " CRYPTO_LIBS " ";
            printf "-s validator-elect-req.fif " wallet_addr;
            printf " " election_start " " MAX_FACTOR " " key_adnl " " ELECTIONS_WORK_DIR "/validator-to-sign.bin ";
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

    awk -v validator="${VALIDATOR_NAME}" -v wallet_addr="${PROXY_ADDR_FROM_DEPOOL_EVENT}" -v TON_BUILD_DIR="${TON_BUILD_DIR}" \
        -v ELECTIONS_WORK_DIR="${ELECTIONS_WORK_DIR}" -v CRYPTO_LIBS="${CRYPTO_LIBS}" -v MAX_FACTOR="${MAX_FACTOR}" '{
        if (NR == 1) {
            election_start = $1 + 0
        } else if (($1 == "got") && ($2 == "public") && ($3 == "key:")) {
            key = $4
        } else if (($1 == "got") && ($2 == "signature")) {
            signature = $3
        } else if (($1 == "created") && ($2 == "new") && ($3 == "key")) {
            printf TON_BUILD_DIR "/crypto/fift ";
            printf "-I " CRYPTO_LIBS " ";
            printf "-s validator-elect-signed.fif " wallet_addr " " election_start " " MAX_FACTOR " " $4;
            printf " " key " " signature " " ELECTIONS_WORK_DIR "/validator-query.boc ";
            print  "> " ELECTIONS_WORK_DIR "/" validator "-request-dump2"
        }
    }' "${ELECTIONS_WORK_DIR}/election-id" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-request-dump1" "${ELECTIONS_WORK_DIR}/${VALIDATOR_NAME}-election-adnl-key" >"${ELECTIONS_WORK_DIR}/elector-run3"

    bash "${ELECTIONS_WORK_DIR}/elector-run3"

    echo "${ACTIVE_ELECTION_ID}" >"${ELECTIONS_WORK_DIR}/election-artefacts-created"
fi

if [ -f "${ELECTIONS_WORK_DIR}/validator-query.boc" ]; then
    validator_query_boc=$(base64 --wrap=0 "${ELECTIONS_WORK_DIR}/validator-query.boc")
else
    echo "ERROR: ${ELECTIONS_WORK_DIR}/validator-query.boc does not exist"
    rm -f "${ELECTIONS_WORK_DIR}/election-artefacts-created"
    exit 1
fi

for i in $(seq ${TONOS_CLI_SEND_ATTEMPTS}); do
    echo "INFO: tonos-cli submitTransaction attempt #${i}..."
    set -x
    if ! "${UTILS_DIR}/tonos-cli" call "${MSIG_ADDR}" submitTransaction \
        "{\"dest\":\"${DEPOOL_ADDR}\",\"value\":\"1000000000\",\"bounce\":true,\"allBalance\":false,\"payload\":\"${validator_query_boc}\"}" \
        --abi "${CONFIGS_DIR}/SafeMultisigWallet.abi.json" \
        --sign "${KEYS_DIR}/msig.keys.json"; then
        echo "INFO: tonos-cli submitTransaction attempt #${i}... FAIL"
    else
        echo "INFO: tonos-cli submitTransaction attempt #${i}... PASS"
        break
    fi
    set +x
done

if [ "$i" = ${TONOS_CLI_SEND_ATTEMPTS} ]; then
    echo "ERROR: unable to send an elector request - ${TONOS_CLI_SEND_ATTEMPTS} attempts failed"
    exit 1
fi

date +"INFO: %F %T prepared for elections"
echo "${ACTIVE_ELECTION_ID}" >"${ELECTIONS_WORK_DIR}/active-election-id-submitted"

echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
