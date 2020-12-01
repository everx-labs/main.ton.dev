#!/bin/bash -eE

#check for the destination wallet

L_PATH="./"
L_FILE="confirmer.log"

function f_output() {
    TS=$(date +%s)
    TD=$(date +%FT%T%Z)
    echo "${TD};${TS};${1}" >>"${L_PATH}${L_FILE}"
    echo "${TD};${TS};${1}"
}

function f_check_trans() {
    W_SOURCE=$1 # Source wallet
    W_DEST=$2   # Destination wallet
    W_PHRASE=$3 # seed phrase
    TRAN=0

    OUTPUT=$(${L_PATH}tonos-cli run "${W_SOURCE}" getTransactions {} --abi ${L_PATH}SafeMultisigWallet.abi.json | sed -ne '/Result/,$ p' | sed 's/Result: //')
    N_TRAN=$(echo "${OUTPUT}" | jq '.transactions | length')

    if [ "${N_TRAN}" == "" ]; then
        f_output "${W_SOURCE};Bad_contract;"
    elif [ "${N_TRAN}" -eq 0 ]; then
        f_output "${W_SOURCE};No_transactions;"
    else
        while [ "${TRAN}" -lt "${N_TRAN}" ]; do
            T_DEST=$(echo "${OUTPUT}" | jq -r ".transactions[${TRAN}].dest")
            T_ID=$(echo "${OUTPUT}" | jq -r ".transactions[${TRAN}].id")
            T_VALUE=$(echo "${OUTPUT}" | jq -r ".transactions[${TRAN}].value")
            T_PAYLOAD=$(echo "${OUTPUT}" | jq -r ".transactions[${TRAN}].payload")
            T_VALUE_D=$(printf "%d\n" "${T_VALUE}")
            if [ "${T_DEST}" == "${W_DEST}" ] && [ "${T_PAYLOAD}" != "te6ccgEBAQEAAgAAAA==" ]; then
                # shellcheck disable=SC2086
                # shellcheck disable=SC2015
                ${L_PATH}tonos-cli call "${W_SOURCE}" confirmTransaction \
                    '{"transactionId":"'${T_ID}'"}' \
                    --abi ${L_PATH}SafeMultisigWallet.abi.json \
                    --sign "${W_PHRASE}" &&
                    f_output "${W_SOURCE};${T_ID};${T_DEST};${T_VALUE_D};Good;" ||
                    f_output "${W_SOURCE};${T_ID};${T_DEST};${T_VALUE_D};Network_error;"
            else
                f_output "${W_SOURCE};${T_ID};${T_DEST};${T_VALUE_D};Bad"
            fi
            TRAN=$((TRAN + 1))
        done
    fi
}

# ========= MAIN

# shellcheck disable=SC2207
WALLETS=($(cat ${L_PATH}wallets.txt))
WALLETS_NUM=$(wc -l ${L_PATH}wallets.txt | awk '{print $1}')
IFS=$'\n'
# shellcheck disable=SC2207
PHRASES=($(cat ${L_PATH}/p.txt))
for i in $(seq 0 $((WALLETS_NUM - 1))); do
    f_check_trans "${WALLETS["$i"]}" -1:3333333333333333333333333333333333333333333333333333333333333333 "${PHRASES["$i"]}"
done
