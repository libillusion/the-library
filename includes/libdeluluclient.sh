# Client wrapper for libworkerdb.
delulu.request() {
  _DELULU_RESPONSE=""
  local _target="/tmp/tmp.$(uuidgen)" DELULU_SOCKET="${DELULU_SOCKET:-/tmp/delulu.sock}"
  mkfifo "$_target"

  local cmd="${1// /_}"
  shift
  local key="${1// /'\space'}"
  shift
  local value="${1}"

  #    authkey                 clientpipe *cmd, key, value
  echo "AUTH=${DELULU_AUTHKEY} ${_target} $cmd $key $value" >"$DELULU_SOCKET"
  read -r _DELULU_RESPONSE_RAW <"$_target"
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
  echo "$_resp"
}
