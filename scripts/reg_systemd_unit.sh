#!/bin/bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

cat <<EOLONGFILE > /etc/systemd/system/tonnode.service
[Unit]
Description=TON Node service
After=network.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
ExecStartPre=$SCRIPT_DIR/env.sh && exit 0
ExecStart=$SCRIPT_DIR/run.sh
RemainAfterExit=yes
StandardOutput=syslog
StandardError=syslog
User=$(whoami)
Group=$(whoami)
Restart=always
RestartSec=120

[Install]
WantedBy=multi-user.target
EOLONGFILE

systemctl daemon-reload

echo 'DONE'
echo ''
echo 'Use "service tonnode start" for start node'
echo 'Use "systemctl enable tonnode" for add to startup'
