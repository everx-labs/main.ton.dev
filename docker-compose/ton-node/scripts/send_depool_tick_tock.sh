#!/bin/bash -eEx

ELECTOR_ADDR="-1:3333333333333333333333333333333333333333333333333333333333333333"
TICK_TOCK_NUMBER="5"
TICK_TOCK_SEND_TIMEOUT="60" # seconds

if [ "${RUST_NET_ENABLE}" = "yes" ]; then
    TON_NODE_ROOT="/ton-node"
    UTILS_DIR="${TON_NODE_ROOT}/tools"
    CONFIGS_DIR="${TON_NODE_ROOT}/configs"
    KEYS_DIR="${CONFIGS_DIR}/keys"
    WORK_DIR="${UTILS_DIR}"
else
    UTILS_DIR="/utils"
    KEYS_DIR="/keys"
    WORK_DIR="/validation"
    CONFIGS_DIR="${WORK_DIR}/configs"
fi

cd ${WORK_DIR}

case ${ELECTOR_TYPE} in
"fift")
    TONOS_CLI_OUTPUT=$(${UTILS_DIR}/tonos-cli runget ${ELECTOR_ADDR} active_election_id 2>&1)
    ACTIVE_ELECTION_ID_HEX=$(echo "${TONOS_CLI_OUTPUT}" | grep "Result:" | awk -F'"' '{print $2}')
    ;;
"solidity")
    TONOS_CLI_OUTPUT=$(${UTILS_DIR}/tonos-cli run ${ELECTOR_ADDR} active_election_id {} --abi ${CONFIGS_DIR}/Elector.abi.json 2>&1)
    ACTIVE_ELECTION_ID_HEX=$(echo "${TONOS_CLI_OUTPUT}" | grep "value0" | awk '{print $2}' | tr -d '"')
    ;;
*)
    echo "ERROR: unknown ELECTOR_TYPE (${ELECTOR_TYPE})"
    exit 1
    ;;
esac

if [ -z "${ACTIVE_ELECTION_ID_HEX}" ]; then
    echo "ERROR: failed to get active elections ID"
    exit 1
fi

ACTIVE_ELECTION_ID=$(printf "%d" "${ACTIVE_ELECTION_ID_HEX}")
echo "INFO: ACTIVE_ELECTION_ID = ${ACTIVE_ELECTION_ID}"

if [ "${ACTIVE_ELECTION_ID}" = "0" ]; then
    date +"INFO: %F %T No current elections"
    exit 0
fi

ELECTIONS_WORK_DIR="${KEYS_DIR}/elections/${ACTIVE_ELECTION_ID}"
mkdir -p "${ELECTIONS_WORK_DIR}"

if [ ! -f "${ELECTIONS_WORK_DIR}/depool-tick-tock-submitted" ]; then
    for i in $(seq 1 ${TICK_TOCK_NUMBER}); do
        echo "INFO: send tick tock #$i ... "
        if timeout "${TICK_TOCK_SEND_TIMEOUT}" ${UTILS_DIR}/tonos-cli depool ticktock; then
            echo "${ACTIVE_ELECTION_ID}" >"${ELECTIONS_WORK_DIR}/depool-tick-tock-submitted"
            echo "INFO: send tick tock #$i ... DONE"
            sleep 60
        else
            echo "WARNING: send tick tock #$i ... FAIL"
        fi
    done
else
    echo "WARNING: depool tick tock has been already sent"
    exit 0
fi
