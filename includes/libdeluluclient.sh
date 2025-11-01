# Client wrapper for libworkerdb.
DELULU_CLIENT_SOCK="${ITMPDIR:-/tmp}/tmp.$(uuidgen)" DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
mkfifo "$DELULU_CLIENT_SOCK"

delulu.request() {
  _DELULU_RESPONSE=""

  # creating resp lock
  if [[ -n "$3" ]]; then
    local cmd="${1// /_}"
    shift
    local key="${1// /'\space'}"
    shift
    local value="${1}"
  else
    local value="${1}"
  fi

  #    authkey                 clientpipe *cmd, key, value
  echo "AUTH=${DELULU_AUTHKEY} ${DELULU_CLIENT_SOCK} $cmd $key $value" >"$DELULU_SOCKET"
  read -t 5 -r _DELULU_RESPONSE_RAW <"$DELULU_CLIENT_SOCK"
  if [[ $? -ne 0 ]]; then
    _DELULU_RESPONSE="err: timed out"
    _DELULU_RESPONSE_RAW="err: timed out"
    return 2
  fi
  case "$_DELULU_RESPONSE_RAW" in
  "ok:"*)
    IFS=": " read -r _ _DELULU_RESPONSE <<<"$_DELULU_RESPONSE_RAW"
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

delulu.request.send() {
  delulu.request $@
  echo "$_DELULU_RESPONSE_RAW"
}

# debugging
delulu.request.raw() {
  local _target="/tmp/tmp.$(uuidgen)" DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
  mkfifo "$_target"

  echo "${_target} $@" >"$DELULU_SOCKET"
  read -r _resp <"$_target"
  _DELULU_RESPONSE="$_resp"
  _DELULU_RESPONSE_RAW="$_resp"
}

delulu.request.raw.send() {
  delulu.request $@
  echo "$_DELULU_RESPONSE_RAW"
}
