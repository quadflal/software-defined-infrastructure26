#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${username}@${server_host} "$@"
# end of script
