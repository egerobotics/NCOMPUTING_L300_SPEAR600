#!/bin/bash
# Simple deploy tool for nComputing L300
# Usage: ./deploy.sh <local_file> [remote_path]

BOARD="root@192.168.1.200"
PASS="root"
SSH="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="sshpass -p $PASS scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if [ -z "$1" ]; then
    echo "Usage: $0 <file> [remote_path]"
    echo "       $0 --cmd <command>"
    exit 1
fi

if [ "$1" = "--cmd" ]; then
    shift
    $SSH $BOARD "$*"
else
    REMOTE_PATH="${2:-/tmp/}"
    $SCP "$1" $BOARD:$REMOTE_PATH
    echo "Deployed $1 -> $REMOTE_PATH"
fi
