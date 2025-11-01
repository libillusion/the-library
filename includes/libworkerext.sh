# Core libraries for ease of use

function worker.ext.open_returnfd() {
  # Reserving 296
  local OUT_PATH="$(mktemp)"
  exec 296<>"$OUT_PATH"
  rm "$OUT_PATH"
  # setting toggle
  REQ_BUILT_RESPONSE=true
}

function @set_header() {
  [ -z "$2" ] && return 1
  REQ_RESPONSE_HEADERS["$(lower "${1}")"]="${2}"
}

function @set_cookie() {
  [ -z "$2" ] && return 1
  REQ_COOKIE_TO_SEND["${1}"]="${2}"
}

function @respond {
  local IS_DISPOSITION=false
  "${REQ_BUILT_RESPONSE}" 2>/dev/null && return
  worker.ext.open_returnfd
  local RESPONSE_CODE="$1"

  [[ -z "$2" ]] && {
    worker.build_response "$1" >&296
    return
  } # immediately build response

  case "$2" in
  json)
    @set_header "content-type" "application/json"
    ;;
  html)
    @set_header "content-type" "text/html"
    ;;
  plain)
    @set_header "content-type" "text/plain"
    ;;
  disposition-inline | file)
    @set_header "content-disposition" "inline; filename=${3:-"$(uuidgen).dat"}"
    ;;
  disposition-attachment | download)
    @set_header "content-disposition" "attachment; filename=${3:-"$(uuidgen).dat"}"
    ;;
  *)
    @set_header "content-type" "$2"
    ;;
  esac

  if read -t 0; then
    # has content
    cat
  else
    printf '%s' "$3"
  fi

  worker.build_response "$1" >&296
}

function @log() {
  printf '%s\n' "$@" >&2
}

####################################
# PRIVILEGED MIDDLEWARE OPERATIONS #
####################################

function @resolve_request() {
  "$REQ_FUNCTION"
}

function @resolve() {
  "$REQ_FUNCTION"
}
