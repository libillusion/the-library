#!/bin/bash
# Anything that's request-related prefixes with REQ_
source libijson.sh
source libworkerdb.sh

# constants
HTTP_STATUS_CODE=(
  [101]="101 Switching Protocols"
  [200]="200 OK"
  [201]="201 Created"
  [301]="301 Moved Permanently"
  [302]="302 Found"
  [400]="400 Bad Request"
  [401]="401 Unauthorized"
  [403]="403 Forbidden"
  [404]="404 Not Found"
  [405]="405 Method Not Allowed"
  [500]="500 Internal Server Error"
)

uuidgen() {
  # Uses Linux's optimized UUID Generrator
  cat /proc/sys/kernel/random/uuid
}

lower() {
  # Usage: lower "string"
  printf '%s\n' "${1,,}"
}

# session
worker.session.get() {
  echo "${REQ_SESSION_DB[${1}]}"
}

worker.session.set() {
  worker.db.eval "${REQ_SESSION_DB[${1}]}=\"${2}\""
}

worker.parse_get_data() {
  local entry
  # Split QUERY_STRING into an assoc, so it can be easy reused
  IFS='?' read -r REQ_PATH get <<<"$REQ_PATH"

  # Url decode get data
  get="$(urldecode "$get")"

  # Split html #
  IFS='#' read -r REQ_PATH _ <<<"$REQ_PATH"
  REQ_PATH="${REQ_PATH#/}" # removes leading slash
  REQ_QUERY_STRING="$get"
  IFS='&' read -ra data <<<"$get"
  for entry in "${data[@]}"; do
    REQ_GET_DATA["${entry%%=*}"]="${entry#*:}"
  done
}

worker.parse_http_headers() {
  local line _h _v
  # Split headers and put it inside HTTP_HEADERS, so it can be reused
  while read -r line; do
    line="${line%%$'\r'}"
    _verbose 3 "$line"
    [[ -z "$line" ]] && return
    _h="${line%%:*}"
    REQ_HEADERS["${_h,,}"]="${line#*: }"
  done
}

worker.parse_cookies_data() {
  local -a cookie
  local entry key value
  IFS=';' read -ra cookie <<<"${HTTP_HEADERS["Cookie"]}"

  for entry in "${cookie[@]}"; do
    IFS='=' read -r key value <<<"$entry"
    REQ_COOKIES["${key# }"]="${value% }"
  done
}

worker.parse_post_data() {
  local entry
  local content_type=$(lower "${HTTP_HEADERS["Content-type"]}")
  # Split POst data into an assoc if is a form, if not create a key raw
  if [[ "$content_type" == "application/x-www-form-urlencoded" ]]; then
    IFS='&' read -rN "${HTTP_HEADERS["Content-Length"]}" -a data
    for entry in "${data[@]}"; do
      entry="${entry%%$'\r'}"
      REQ_POST_DATA["${entry%%=*}"]="${entry#*:}"
    done
  elif [[ "$content_type" == "application/json" ]]; then
    read -rN "${HTTP_HEADERS["Content-Length"]}" data
    REQ_POST_DATA_RAW="${data%%$'\r'}"
    ijson_parse_to REQ_POST_DATA <<<"$REQ_POST_DATA_RAW"
  else
    read -rN "${HTTP_HEADERS["Content-Length"]}" data
    REQ_POST_DATA_RAW="${data%%$'\r'}"
  fi
}

# response building
worker.build_response_headers() {
  printf '%s %s\n' "$REQ_HTTP_VERSION" "${REQ_HTTP_RESPONSE_HEADERS['status']}"
  unset 'REQ_HTTP_RESPONSE_HEADERS["status"]'

  # return cookies
  for value in "${REQ_COOKIE_TO_SEND[@]}"; do
    printf 'Set-Cookie: %s\n' "$value"
  done

  # return headers
  for key in "${!REQ_HTTP_RESPONSE_HEADERS[@]}"; do
    printf '%s: %s\n' "${key,,}" "${REQ_HTTP_RESPONSE_HEADERS[$key]}"
  done
}

worker.build_response() {
  local REQ_RESPONSE_CODE="${1:-200}"
  # set status
  REQ_HTTP_RESPONSE_HEADERS['status']="${HTTP_STATUS_CODE[${REQ_RESPONSE_CODE}]}"

  if [[ "$REQ_RESPONSE_CODE" == "401" ]]; then
    REQ_HTTP_RESPONSE_HEADERS['WWW-Authenticate']="Basic realm=WebServer"
    req.build_response_headers
    return
  fi

  HTTP_RESPONSE_HEADERS["content-length"]=$(stat -c %s /proc/self/fd/99)
  req.build_response_headers
  printf '\n'

  cat <&99 # outputs content
  printf '\n'
}

worker.build_error_response() {
  local ERROR_CODE=${1:-500}
  local HTTP_STATUS=${HTTP_STATUS_CODE["$ERROR_CODE"]}
  if [ ! -v "WORKER_ERROR_HTML" ]; then
    echo "<title>${ERROR_CODE} ${HTTP_STATUS}</title><center><h1>${ERROR_CODE} ${HTTP_STATUS}<h1><p>Illusion Server</p></center>" >&99
  fi
  worker.build_response
}

worker.process_request_data() {
  # We'll reset them again
  local REQ_METHOD REQ_PATH REQ_PATH_RAW REQ_HTTP_VERSION REQ_QUERY_STRING REQ_POST_DATA_RAW
  local -A REQ_HEADERS
  local -A REQ_POST_DATA
  local -A REQ_GET_DATA
  local -A REQ_HTTP_RESPONSE_HEADERS
  local -A REQ_COOKIES
  local -A REQ_SESSION
  local -A REQ_COOKIE_TO_SEND
  # ijson REQ_POST_DATA

  # parse http request
  read -r REQ_METHOD REQ_PATH_RAW REQ_HTTP_VERSION
  REQ_HTTP_VERSION="${REQ_HTTP_VERSION%%$'\r'}"

  # parsing request path
  local -A REQ_PATH_PROC
  REQ_PATH="${REQ_PATH_RAW%%\?*}" # removes query string
  worker.parse_http_headers

  worker.parse_get_data

  worker.parse_cookies_data

  if [[ "${REQ_COOKIES["X-Illusion-Session"]}" == *..* ]]; then
    REQ_SESSION_ID="$(uuidgen)"
  else
    REQ_SESSION_ID="${REQ_COOKIES["$"]}"
  fi

  if [[ ! -v "${REQ_SESSION_DB}" ]]; then
    # if the session id is not set
    worker.db.create "wdb_${REQ_SESSION_ID}"
  fi

  declare -n REQ_SESISON_DB="wdb_${REQ_SESSION_ID}"

  if [[ "$REQ_METHOD" == "POST" ]] && ((${REQ_HTTP_HEADERS['Content-Length']} > 0)); then
    worker.parse_post_data
  fi

  # create a temporary file
  REQ_OUT_PATH="$(mktemp)"
  rm "$REQ_OUT_PATH" # immediately remove the file

  worker.process_path

  exec 99<>"$REQ_OUT_PATH"
  # fd 99 is open!
}

worker.cleanup_request() {
  # closes fd 99
  exec 99>&-
}

worker.process_path() {
  # see if path exists
  local REQ_FUNCTION="${WORKER_ROUTES["${REQ_PATH}"]}"

  if [[ -z "$REQ_FUNCTION" ]]; then
    worker.build_error_response 404
  fi
}

worker.process_request() {
  worker.process_request_data

  worker.cleanup_request
}
