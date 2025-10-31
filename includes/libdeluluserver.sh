# The Delusional Database
delulu.instance() {
  DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
  rm -f "$DELULU_SOCKET"
  mkfifo "$DELULU_SOCKET"
  echo "Started Delulu Server (listening on $DELULU_SOCKET)"

  send() {
    printf '%s\n' "$1" >"$client_pipe"
    #echo "$1"
  }

  ok() {
    send "ok: $1"
  }

  err() {
    send "err: $1"
  }

  if [[ "$DELULU_AUTHKEY" == "null" ]] || [[ -z "$DELULU_AUTHKEY" ]]; then
    # wait for initialization
    while read -r client_pipe cmd value <"$DELULU_SOCKET"; do
      case "$cmd" in
      kill)
        exit
        ;;
      init)
        DELULU_AUTHKEY="$value"
        send "auth: init ok"
        break
        ;;
      *)
        err "invalid operation"
        echo "client-exec: $cmd $value"
        ;;
      esac
    done
  fi

  declare -A DB # very good
  while read \
    auth_segment client_pipe \
    cmd key value <"$DELULU_SOCKET"; do

    echo "Received operation $cmd"

    if [[ "$auth_segment" != "AUTH=$DELULU_AUTHKEY" ]]; then
      echo "err: auth failed" >"$client_pipe"
      continue
    fi

    case "$cmd" in
    SET)
      DB["$key"]="$value"
      ok "set ok"
      ;;
    GET)
      if [[ -v DB["$key"] ]]; then
        ok "${DB["$key"]}"
      else
        err "key not found"
      fi
      ;;
    DUMP)
      if [[ "${#DB[@]}" -lt 1 ]]; then
        ok "database empty"
      else
        declaration=$(declare -p DB)
        declaration=${declaration#*=}
        printf "ok: $declaration" >"$client_pipe"
        declaration=""
      fi
      ;;
    DUMP_KEYS)
      if [[ "${#DB[@]}" -lt 1 ]]; then
        ok "database empty"
      else
        keys="${!DB[@]}"
        printf "ok: $keys" >"$client_pipe"
        keys=""
      fi
      ;;
    COUNT)
      ok "${#DB[@]}"
      ;;
    MEMORY)
      ok "$(awk '{ printf "%.2f\n", $2 * 4096 / 1024 / 1024 }' /proc/self/statm)MB"
      ;;

    *)
      echo hi
      err "invalid operation"
      ;;
    esac
  done
}

delulu.server() {
  # consts
  local DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}" \
    DELULU_FORCE=false

  # parsing arguments
  while getopts ":vf:" opt; do
    for i in "$@"; do
      case "$1" in
      -s | --socket)
        DELULU_SOCKET="${i#*=}"
        ;;
      -f | --force)
        DELULU_FORCE
        ;;
      -a | --authkey)
        DELULU_AUTHKEY="${i#*=}"
        ;;
      esac
    done
  done

  # Check to see if Delulu socket already exists
  if [[ -f "$DELULU_SOCKET" ]]; then
    if "$DELULU_FORCE"; then
      rm -f "$DELULU_SOCKET"
    else
      raise INVALIDCONF "Delulu socket already exists in $DELULU_SOCKET."
    fi
  fi

  # Exclusively using the 296 lock.
  local DELULU_OUTFILE=$(mktemp)
  exec 296<>"$DELULU_OUTFILE"
  rm "$DELULU_OUTFILE"

  echo "DELULU_SOCKET=\"$DELULU_SOCKET\"" >&296
  echo "DELULU_AUTHKEY=\"$DELULU_AUTHKEY\"" >&296
  declare -f delulu.instance | sed '1,2d;$d' >&296
  /usr/bin/env bash /proc/self/fd/296
}
