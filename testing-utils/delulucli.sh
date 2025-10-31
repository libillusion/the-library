#!/bin/bash
OUTPUT="/tmp/tmp.$(uuidgen)"
mkfifo "$OUTPUT"
DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
[[ -z "$DELULU_AUTHKEY" ]] && {
  echo "no auth key"
  exit
}

display_help() {
  cat <<EOF
commands
.exit => exit
EOF
}

KEYWORDS=(
  "GET"
  "SET"
  "DUMP"
  "DUMP_KEYS"
  ".exit"
  ".help"
)

source includes/libdeluluclient.sh
echo "Found instance at $DELULU_SOCKET" || exit 1

while true; do
  read -rp "delulu> " command
  IFS=" " read -r cmd key value <<<"$command"

  case "$command" in
  .exit)
    exit
    ;;
  .help)
    display_help
    continue
    ;;
  esac

  bench_start=$(date +%s%N)
  delulu.request "$cmd" "$key" "$value"

  echo "($(awk "BEGIN { printf \"%.2fms\n\", ($(($(date +%s%N) - $bench_start)) / 1000000) }")) $_DELULU_RESPONSE_RAW"
done
