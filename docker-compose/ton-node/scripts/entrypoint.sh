#!/bin/bash -eEx

TON_NODE_ROOT_DIR="/ton-node"
TON_NODE_CONFIGS_DIR="${TON_NODE_ROOT_DIR}/configs"
TON_NODE_SCRIPTS_DIR="${TON_NODE_ROOT_DIR}/scripts"
TON_NODE_LOGS_DIR="${TON_NODE_ROOT_DIR}/logs"

echo "INFO: R-Node startup..."

echo "INFO: NETWORK_TYPE = ${NETWORK_TYPE}"
echo "INFO: DEPLOY_TYPE = ${DEPLOY_TYPE}"
echo "INFO: CONFIGS_PATH = ${CONFIGS_PATH}"
echo "INFO: \$1 = $1"
echo "INFO: \$2 = $2"

NODE_EXEC="${TON_NODE_ROOT_DIR}/ton_node_kafka"
if [ "${TON_NODE_ENABLE_KAFKA}" -ne 1 ]; then
    echo "INFO: Kafka disabled"
    NODE_EXEC="${TON_NODE_ROOT_DIR}/ton_node_no_kafka"
else
    echo "INFO: Kafka enabled"
fi

function f_get_ton_global_config_json() {
    curl -sS "https://raw.githubusercontent.com/tonlabs/main.ton.dev/master/configs/ton-global.config.json" -o "${TON_NODE_CONFIGS_DIR}/ton-global.config.json"
}

function f_iscron() {
    if ! grep "validator.sh" /etc/crontab >/dev/null 2>&1; then
        {
            echo "RUST_NET_ENABLE=yes"
            echo "VALIDATOR_NAME=\"${VALIDATOR_NAME}\""
            echo "SDK_URL=\"${SDK_URL}\""
            echo "SDK_ENDPOINT_URL_LIST=\"${SDK_ENDPOINT_URL_LIST}\""
            echo "ELECTOR_TYPE=\"${ELECTOR_TYPE}\""
        } >>/etc/crontab
        if [ "${DEPOOL_ENABLE}" = "yes" ]; then
            {
                echo "DEPOOL_ENABLE=yes"
                echo "* * * * *    root  ${TON_NODE_SCRIPTS_DIR}/send_depool_tick_tock.sh >>${TON_NODE_LOGS_DIR}/send_depool_tick_tock.log 2>&1"
                echo "*/5 * * * *     root  ${TON_NODE_SCRIPTS_DIR}/validator.sh >>${TON_NODE_LOGS_DIR}/validator.log 2>&1"
            } >>/etc/crontab
        else
            {
                echo "STAKE=$STAKE"
                echo "*/2 * * * *  root  ${TON_NODE_SCRIPTS_DIR}/validator.sh \${STAKE} >>${TON_NODE_LOGS_DIR}/validator.log 2>&1"
            } >>/etc/crontab
        fi
    fi

    chmod +x ${TON_NODE_SCRIPTS_DIR}/validator.sh
    pgrep cron >/dev/null || cron
}

# main
apt update && apt install -y cron jq wget
[ "$2" = "validate" ] && f_iscron
f_get_ton_global_config_json

if [ "$1" = "bash" ]; then
    tail -f /dev/null
else
    cd ${TON_NODE_ROOT_DIR}
    # shellcheck disable=SC2086
    #exec ${NODE_EXEC}_compression --configs "${CONFIGS_PATH}" ${TON_NODE_EXTRA_ARGS} >>${TON_NODE_LOGS_DIR}/stdout.log \
    exec ${NODE_EXEC} --configs "${CONFIGS_PATH}" ${TON_NODE_EXTRA_ARGS} >>${TON_NODE_LOGS_DIR}/stdout.log \
        2>>${TON_NODE_LOGS_DIR}/stderr.log
fi
