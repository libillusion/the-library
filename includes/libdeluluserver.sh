# The Delusional Database
delulu.instance() {
  DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}" 
  DELULU_AUTHKEY="null"
  rm -f "$DELULU_SOCKET"
  mkfifo "$DELULU_SOCKET"

  # wait for initialization
  while read -r cmd value <"$DELULU_SOCKET"; do
    case "$cmd" in
      kill)
        exit
        ;;
      init)
        DELULU_AUTHKEY="$value"
        echo "auth: init ok"
        break
        ;;
      *)
        echo "$cmd $value"
        break
        ;;
    esac
  done

  declare -A DB # very good
  while read -r \
    auth_segment client_pipe \
    cmd key value <"$DELULU_SOCKET"; do

    if [[ "$auth_segment" != "AUTH=$DELULU_AUTHKEY" ]]; then
      echo "err: auth failed" >"$client_pipe"
      continue
    fi
 
    case "$cmd" in
      SET)
        DB["$key"]="$value"
        echo "ok: set ok" >"$client_pipe"
        ;;
      GET)
        if [[ -v "${DB["$key"]}" ]]; then
          printf 'ok: %s\n' "${DB["$key"]}" >"$client_pipe"
        else
          echo "err: key not found" >"$client_pipe"
        fi
        ;;
      DUMP)
        printf "ok: " >"$client_pipe"
        declare -p DB >"$client_pipe"
        ;;
    esac
  done
}

delulu.server() {
  # consts
  local DELULU_SOCKET="/tmp/delulu.sock" \
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

  # Exclusively using the 296 lock. 
  local DELULU_OUTFILE=$(mktemp)
  exec 296<>"$DELULU_OUTFILE"
  rm "$DELULU_OUTFILE"

  export DELULU_SOCKET
  define -f delulu.instance | sed '1,2d;$d' >&296
}
