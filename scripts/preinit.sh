#!/bin/bash -eE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

echo "INFO: TON node preinit..."

SETUP_USER="$(id --user)"
SETUP_GROUP="$(id --group)"

HOSTNAME=$(hostname)
TMP_DIR="/tmp/$(basename "$0" .sh)_$$"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

echo "INFO: Getting my public IP..."
until [ "$(echo "${IP_ADDRESS}" | grep "\." -o | wc -l)" -eq 3 ]; do
    set +e
    IP_ADDRESS="$(curl -sS ipv4bot.whatismyipaddress.com)"
    set -e
done
NODE_ADDRESS="${IP_ADDRESS}:${ADNL_PORT}"
echo "INFO: NODE_ADDRESS = ${NODE_ADDRESS}"

sudo rm -rf "${TON_WORK_DIR}"
sudo mkdir -p "${TON_WORK_DIR}"
sudo chown "${SETUP_USER}:${SETUP_GROUP}" "${TON_WORK_DIR}"
mkdir -p "${TON_WORK_DIR}/etc"
mkdir -p "${TON_WORK_DIR}/db"
NODE_PREINIT_CONFIGS_DIR="${CONFIGS_DIR}/preinit_${IP_ADDRESS}"
rm -rf "${NODE_PREINIT_CONFIGS_DIR}"
mkdir -p "${NODE_PREINIT_CONFIGS_DIR}"

date | gawk '{
    print "{";
    print "    \"@type\": \"config.global\",";
    print "    \"dht\": {";
    print "        \"@type\": \"dht.config.global\",";
    print "        \"k\": 6,";
    print "        \"a\": 3,";
    print "        \"static_nodes\": {";
    print "            \"@type\": \"dht.nodes\",";
    print "            \"nodes\": [";
    print "            ]";
    print "        }";
    print "    },";
    print "    \"validator\": {";
    print "        \"@type\": \"validator.config.global\",";
    print "        \"zero_state\": {";
    print "            \"workchain\": -1,";
    print "            \"shard\": -9223372036854775808,";
    print "            \"seqno\": 0,";
    print "            \"root_hash\": \"VCSXxDHhTALFxReyTZRd8E4Ya3ySOmpOWAS4rBX9XBY=\",";
    print "            \"file_hash\": \"VCSXxDHhTALFxReyTZRd8E4Ya3ySOmpOWAS4rBX9XBY=\"";
    print "        }";
    print "    }";
    print "}"
}' >"${TON_WORK_DIR}/etc/ton-global.fakeconfig.json"

"${TON_BUILD_DIR}/validator-engine/validator-engine" \
    --global-config "${TON_WORK_DIR}/etc/ton-global.fakeconfig.json" \
    --db "${TON_WORK_DIR}/db" \
    --ip "${NODE_ADDRESS}"

sudo mkdir -p "${KEYS_DIR}"
sudo chown "${SETUP_USER}:${SETUP_GROUP}" "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}"

cd "${KEYS_DIR}"

# Node key
"${UTILS_DIR}/generate-random-id" -m keys -n server >"${KEYS_DIR}/keys_s"
mv "${KEYS_DIR}/server" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_s")"

# Validator (temporary key)
"${UTILS_DIR}/generate-random-id" -m keys -n validator >"${KEYS_DIR}/keys_v"
mv "${KEYS_DIR}/validator" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_v")"
# First four bytes are tag
dd skip=4 count=32 if="${KEYS_DIR}/validator.pub" of="${NODE_PREINIT_CONFIGS_DIR}/${IP_ADDRESS}-key.pub" bs=1 status=none

# Validator ADNL key
"${UTILS_DIR}/generate-random-id" -m keys -n adnl >"${KEYS_DIR}/keys_a"
mv "${KEYS_DIR}/adnl" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_a")"

# Liteserver key
"${UTILS_DIR}/generate-random-id" -m keys -n liteserver >"${KEYS_DIR}/keys_l"
mv "${KEYS_DIR}/liteserver" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_l")"

# Console key
"${UTILS_DIR}/generate-random-id" -m keys -n client >"${KEYS_DIR}/keys_c"

# Update ${TON_WORK_DIR}/db/config.json
awk -v LITESERVER_PORT="${LITESERVER_PORT}" '{
    if (NR == 1) {
        server_id = $2
    } else if (NR == 2) {
        client_id = $2
    } else if (NR == 3) {
        liteserver_id = $2
    } else if (NR == 4) {
        validator_id = $2
    } else if (NR == 5) {
        adnl_id = $2
    } else {
        print $0;
        if ($1 == "\"adnl\"") {
            print "      {";
            print "         \"id\": \"" validator_id "\",";
            print "         \"category\": 0";
            print "      },"
            print "      {";
            print "         \"id\": \"" adnl_id "\",";
            print "         \"category\": 0";
            print "      },"
        } else if ($1 == "\"control\"") {
            print "      {";
            print "         \"id\": \"" server_id "\",";
            print "         \"port\": 3030,";
            print "         \"allowed\": [";
            print "            {";
            print "               \"id\": \"" client_id "\",";
            print "               \"permissions\": 15";
            print "            }";
            print "         ]";
            print "      }"
        } else if ($1 == "\"liteservers\"") {
            print "      {";
            print "         \"id\": \"" liteserver_id "\",";
            print "         \"port\": " LITESERVER_PORT;
            print "      }"
        } else if ($1 == "\"validators\"") {
            expire = systime() + 100000;
            print "      {";
            print "         \"id\": \"" server_id "\",";
            print "         \"temp_keys\": [";
            print "            {";
            print "               \"key\": \"" validator_id "\",";
            print "               \"expire_at\": " expire;
            print "            }";
            print "         ],";
            print "         \"adnl_addrs\": [";
            print "            {";
            print "               \"id\": \"" adnl_id "\",";
            print "               \"expire_at\": " expire;
            print "            }";
            print "         ],";
            print "         \"expire_at\": " expire;
            print "      }"
        }
    }
}' "${KEYS_DIR}/keys_s" "${KEYS_DIR}/keys_c" "${KEYS_DIR}/keys_l" "${KEYS_DIR}/keys_v" "${KEYS_DIR}/keys_a" \
    "${TON_WORK_DIR}/db/config.json" >"${TMP_DIR}/config.json.tmp"
mv -f "${TMP_DIR}/config.json.tmp" "${TON_WORK_DIR}/db/config.json"

awk '{
    if ($3 == "\"engine.dht\",") {
        line = NR + 1
    } else if ((line > 0) && (line == NR)) {
        system("echo " $3 " | base64 -d | od -t x1 -An | tr -d \" \\n\"")
    }
}' "${TON_WORK_DIR}/db/config.json" >"${NODE_PREINIT_CONFIGS_DIR}/${IP_ADDRESS}-dht"

awk -v validator="${IP_ADDRESS}" -v ADNL_PORT="${ADNL_PORT}" -v UTILS_DIR="${UTILS_DIR}" -v TON_WORK_DIR="${TON_WORK_DIR}" \
    -v NODE_PREINIT_CONFIGS_DIR="${NODE_PREINIT_CONFIGS_DIR}" '{
    if (NR == 1) {
        key = toupper($1)
    } else if ($1 == "\"ip\"") {
        ip = $3
        printf UTILS_DIR "/generate-random-id -m dht -a ";
        printf "\"{";
        printf "    \\\"@type\\\" : \\\"adnl.addressList\\\",";
        printf "    \\\"addrs\\\" : [";
        printf "        {";
        printf "            \\\"@type\\\" : \\\"adnl.address.udp\\\",";
        printf "            \\\"ip\\\" : " ip;
        printf "            \\\"port\\\" : " ADNL_PORT;
        printf "        }";
        printf "    ]";
        printf "}\" ";
        printf "-k " TON_WORK_DIR "/db/keyring/" key;
        print  " > " NODE_PREINIT_CONFIGS_DIR "/" validator "-dht"
    }
}' "${NODE_PREINIT_CONFIGS_DIR}/${IP_ADDRESS}-dht" "${TON_WORK_DIR}/db/config.json" >"${TMP_DIR}/cmd.sh"
cat "${TMP_DIR}/cmd.sh"
chmod +x "${TMP_DIR}/cmd.sh"
"${TMP_DIR}/cmd.sh"
rm -f "${TMP_DIR}/cmd.sh"

cd "${NODE_PREINIT_CONFIGS_DIR}" && tar cfz "${CONFIGS_DIR}/preinit_${IP_ADDRESS}.tgz" ./*
md5sum "${CONFIGS_DIR}/preinit_${IP_ADDRESS}.tgz" | awk '{print $1}' >"${CONFIGS_DIR}/preinit_${IP_ADDRESS}.md5"

rm -rf "${TMP_DIR}"

echo "INFO: TON node preinit... DONE"
