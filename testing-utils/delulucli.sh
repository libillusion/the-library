#!/bin/bash
source includes/libdeluluclient.sh
DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
DELULU_PROMPT="delulu"
[[ -z "$DELULU_AUTHKEY" ]] && {
  echo ">>> No auth key, attempting to ping..."

  delulu.request "PING"
  if [[ "$_DELULU_RESPONSE_RAW" == "ok: PONG" ]]; then
    echo ">>> Server is not in bootstrap mode."
    echo "    You MUST include DELULU_AUTHKEY."
    exit 1
  fi

  echo "[!] You're in bootstrap mode, go ahead and initialize the server."
  DELULU_RAWMODE=1
  DELULU_PROMPT="bootstrap"
}

display_help() {
  cat <<EOF
commands
.exit => exit
.raw => send RAW request
EOF
}

KEYWORDS=(
  "GET"
  "SET"
  "DUMP"
  "DUMP_KEYS"
)

echo "Found instance at $DELULU_SOCKET" || exit 1

while true; do
  read -rp "${DELULU_PROMPT}> " command
  IFS=" " read -r cmd key value <<<"$command"

  [[ "$DELULU_RAWMODE" == "1" ]] && IS_RAW=1 || IS_RAW=0

  case "$command" in
  .exit)
    exit
    ;;
  .raw)
    IS_RAW=1
    cmd="$key"
    read -r key value <<<"$value"
    ;;
  .help)
    display_help
    continue
    ;;

  esac

  bench_start=$(date +%s%N)
  if [[ "$IS_RAW" == "1" ]]; then
    delulu.request.raw "$cmd" "$key" "$value"
  else
    delulu.request "$cmd" "$key" "$value"
  fi

  echo "($(awk "BEGIN { printf \"%.2fms\n\", ($(($(date +%s%N) - $bench_start)) / 1000000) }")) $_DELULU_RESPONSE_RAW"
  if [[ "$DELULU_RAWMODE" == "1" ]]; then
    if [[ "$_DELULU_RESPONSE_RAW" == "auth: init ok" ]]; then
      echo ">>> Auth OK, switching to normal mode"
      export DELULU_AUTHKEY="$key"
      declare -g DELULU_PROMPT="delulu"
      declare -g DELULU_RAWMODE=0
    fi
  fi
done
