# Client wrapper for libworkerdb.
delulu.request() {
  local _target="/tmp/tmp.$(uuidgen)"
  mkfifo "$_target"

  #    authkey                 clientpipe *cmd, key, value
  echo "AUTH=${DELULU_AUTHKEY} ${_target} $@" >"$DELULU_SOCKET"
  read -r _resp <"$_target"
  case "$_resp" in
  "ok:"*)
    IFS=":" read -r _ _DELULU_RESPONSE <"$resp"
    return 0
    ;;
  *)
    _DELULU_RESPONSE="$resp"
    return -1
    ;;
  esac
}

req.session.create() {
  # does nothing
  sleep 0
}

req.session.get() {
  local _DELULU_RESPONSE
}
