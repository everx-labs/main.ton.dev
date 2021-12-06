#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

echo "INFO: setup TON node..."

SETUP_USER="$(id --user)"
SETUP_GROUP="$(id --group)"

echo "INFO: Getting my public IP..."
until [ "$(echo "${MY_ADDR}" | grep "\." -o | wc -l)" -eq 3 ] ; do
    set +e
    MY_ADDR="$(curl -sS https://ip.me/)":${ADNL_PORT}
    set -e
done
echo "INFO: MY_ADDR = ${MY_ADDR}"

if [ -d "${TON_WORK_DIR}" ]; then
    echo "ERROR: ${TON_WORK_DIR} exists, remove it (if needed) before new node setup"
    exit 1
fi

sudo mkdir -p "${TON_WORK_DIR}"
sudo chown "${SETUP_USER}:${SETUP_GROUP}" "${TON_WORK_DIR}"
mkdir -p "${TON_WORK_DIR}/etc"
mkdir -p "${TON_WORK_DIR}/db"

cp "${CONFIGS_DIR}/ton-global.config.json" "${TON_WORK_DIR}/etc/ton-global.config.json"

echo "INFO: generate initial ${TON_WORK_DIR}/db/config.json..."
"${TON_BUILD_DIR}/validator-engine/validator-engine" -C "${TON_WORK_DIR}/etc/ton-global.config.json" --db "${TON_WORK_DIR}/db" --ip "${MY_ADDR}"

sudo mkdir -p "${KEYS_DIR}"
sudo chown "${SETUP_USER}:${SETUP_GROUP}" "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}"

cd "${KEYS_DIR}"

declare -A KEYS=( [server]=keys_s [liteserver]=keys_l [client]=keys_c )
for k in "${!KEYS[@]}"; do
    if [ ! -f "${KEYS_DIR}/$k" ] || [ ! -f "${KEYS_DIR}/${KEYS[$k]}" ]; then
        "${UTILS_DIR}/generate-random-id" -m keys -n "${KEYS_DIR}/$k" > "${KEYS_DIR}/${KEYS[$k]}"
    fi
done

chmod 600 "${KEYS_DIR}"/*

find "${KEYS_DIR}"

cp "${KEYS_DIR}/server" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_s")"
cp "${KEYS_DIR}/liteserver" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_l")"

awk '{
    if (NR == 1) {
        server_id = $2
    } else if (NR == 2) {
        client_id = $2
    } else if (NR == 3) {
        liteserver_id = $2
    } else {
        print $0;
        if ($1 == "\"control\"") {
            print "      {";
            print "         \"id\": \"" server_id "\","
            print "         \"port\": 3030,"
            print "         \"allowed\": ["
            print "            {";
            print "               \"id\": \"" client_id "\","
            print "               \"permissions\": 15"
            print "            }";
            print "         ]"
            print "      }";
        } else if ($1 == "\"liteservers\"") {
            print "      {";
            print "         \"id\": \"" liteserver_id "\","
            print "         \"port\": 3031"
            print "      }";
        }
    }
}' "${KEYS_DIR}/keys_s" "${KEYS_DIR}/keys_c" "${KEYS_DIR}/keys_l" "${TON_WORK_DIR}/db/config.json" > "${TON_WORK_DIR}/db/config.json.tmp"

mv "${TON_WORK_DIR}/db/config.json.tmp" "${TON_WORK_DIR}/db/config.json"

find "${TON_WORK_DIR}"

echo "INFO: setup TON node... DONE"
