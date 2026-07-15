#!/usr/bin/env bash
set -e
ip="$1"
key="$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null)"
jq -n --arg key "$key" '{ key: $key }'