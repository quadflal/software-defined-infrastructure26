#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ... ${username}@${server_host} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
# end of script
