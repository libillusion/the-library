# All request-based functions for workers
# session
req.session.get() {
  [ -z "$1" ] && return 1
  local DATA="${REQ_SESSION_DB["${1}"]}"
  [[ -z "$DATA" ]] && return 1
  echo "$DATA"
}

req.session.get_to() {
  [ -z "$2" ] && return 1
  local -n output="$1"
  output="${REQ_SESSION_DB["${2}"]}"
}

req.session.set() {
  local DATA="${REQ_SESSION_DB["${1}"]:-""}"
  [[ "$DATA" == "$2" ]] && return
  worker.db.eval "wdb_${REQ_SESSION_ID}[\"${1//\"/\\\"}\"]=\"${2//\"/\\\"}\""
}

req.session.create() {
  [ -z "$1" ] && return 1
  if ! worker.db.exists "$1"; then
    worker.db.create "wdb_$1"
  fi
}

# function aliases
req.data.get() { REQ_POST_DATA.get $@; }
req.data.get_to() { REQ_POST_DATA.get_to $@; }
req.query.get() { [[ -n "$1" ]] && printf '%s\n' "${REQ_QUERIES["$1"]}"; }
req.query.get_to() { [[ -n "$2" ]] && "$2"="${REQ_QUERIES["$1"]}"; }

req.response.get() { cat /proc/self/fd/299; }

# INTERNALS
function req.response._openfd() {
  # Reserving 295
  local OUT_PATH="$(mktemp)"
  exec 295<>"$OUT_PATH"
  rm "$OUT_PATH"
  # setting toggle
  REQ_BUILT_RESPONSE=true
}

# same thing
req.response.set.from_args() {
  printf "%s" "$@" >/proc/self/fd/299
}
req.response.set.from_text() {
  printf "%s" "$@" >/proc/self/fd/299
}

req.response.set.from_stdin() {
  req.response._openfd
  # race condition if we dont' do this
  cat >/proc/self/fd/295
  cat /proc/self/fd/295 >/proc/self/fd/299
  exec 295>&- # close fd
}

req.response.set.from_pipe() {
  req.response._openfd
  # race condition if we dont' do this
  cat >/proc/self/fd/295
  cat /proc/self/fd/295 >/proc/self/fd/299
  exec 295>&- # close fd
}

req.response.set.from_variable() {
  local -n _input="$1"
  printf '%s\n' "$_input" >/proc/self/fd/299
}
