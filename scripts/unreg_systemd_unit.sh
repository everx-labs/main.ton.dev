#!/bin/bash

service tonnode stop > /dev/null 2>&1
systemctl disable tonnode > /dev/null 2>&1
rm /etc/systemd/system/tonnode.service > /dev/null 2>&1
echo 'DONE'
