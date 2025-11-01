#!/bin/bash
# Anything that's request-related prefixes with REQ_
source ${IPREFIX}/libijson.sh
source ${IPREFIX}/libworkerdb.sh
source ${IPREFIX}/libworkerrequest.sh

# constants
declare -Ag WORKER_HTTP_STATUS_CODE=(
  # 1xx Informational
  [100]="100 Continue"
  [101]="101 Switching Protocols"
  [103]="103 Early Hints"

  # 2xx Success
  [200]="200 OK"
  [201]="201 Created"
  [202]="202 Accepted"
  [203]="203 Non-Authoritative Information"
  [204]="204 No Content"
  [205]="205 Reset Content"
  [206]="206 Partial Content"

  # 3xx Redirection
  [300]="300 Multiple Choices"
  [301]="301 Moved Permanently"
  [302]="302 Found"
  [303]="303 See Other"
  [304]="304 Not Modified"
  [307]="307 Temporary Redirect"
  [308]="308 Permanent Redirect"

  # 4xx Client Error
  [400]="400 Bad Request"
  [401]="401 Unauthorized"
  [402]="402 Payment Required"
  [403]="403 Forbidden"
  [404]="404 Not Found"
  [405]="405 Method Not Allowed"
  [406]="406 Not Acceptable"
  [408]="408 Request Timeout"
  [409]="409 Conflict"
  [410]="410 Gone"
  [413]="413 Payload Too Large"
  [414]="414 URI Too Long"
  [415]="415 Unsupported Media Type"
  [429]="429 Too Many Requests"
  [431]="431 Request Header Fields Too Large"
  [451]="451 Unavailable For Legal Reasons"

  # 5xx Server Error
  [500]="500 Internal Server Error"
  [501]="501 Not Implemented"
  [502]="502 Bad Gateway"
  [503]="503 Service Unavailable"
  [504]="504 Gateway Timeout"
  [505]="505 HTTP Version Not Supported"
)

declare -a WORKER_HANDLE_CALL_HOOKS=()
declare -a WORKER_HANDLE_RESPONSE_HOOKS=()

declare -a WORKER_FUNCTIONS_TO_EXPORT=()
declare -a WORKER_VARIABLES_TO_EXPORT=()

# Utilities functions

uuidgen() {
  # Uses Linux's optimized UUID Generrator
  cat /proc/sys/kernel/random/uuid | sed 's+-+_+g'
}

lower() {
  # Usage: lower "string"
  printf '%s\n' "${1,,}"
}

urldecode() {
  local url_encoded="${1//+/ }"
  printf '%b\n' "${url_encoded//%/\\x}"
}

##########################
# WORKER PLUGIN HANDLERS #
##########################
worker.hooks.add() {
  # worker.hooks.[function_name]
  local fn="$1"
  case "$fn" in
  *worker.hooks.handle_call)
    WORKER_HANDLE_CALL_HOOKS+=("$fn")
    ;;
  *worker.hooks.handle_response)
    WORKER_HANDLE_RESPONSE_HOOKS+=("$fn")
    ;;
  esac
}

worker.hooks.load() {
  # check all functions
  for fn in $(declare -F | grep "worker.hooks." | awk '{print $3}'); do
    worker.hooks.add "$fn"
  done
}

worker.export.add_fn() {
  # add export
  WORKER_FUNCTIONS_TO_EXPORT+=("$1")
}

worker.export.add_fn.with_prefix() {
  # adding export with prefix
  local fnprefix="$1"

  for fn in $(declare -gF | awk '{print $3}' | grep "^${fnprefix}."); do
    worker.export.add_fn "$fn"
  done
}

worker.export.add_var() {
  WORKER_VARIABLES_TO_EXPORT+=("$1")
}

worker.export.add_var.with_prefix() {
  # adding export with prefix
  local varprefix="$1"

  for var in $(declare -gp | awk '{print $3}' | grep "^${varprefix}"); do
    IFS="=" read -r varname _ <<<"$var"
    worker.export.add_var "$varname"
  done
}

#######################
# WORKER SUBFUNCTIONS #
#######################

worker.parse_get_data() {
  local entry
  # Split QUERY_STRING into an assoc, so it can be easy reused
  IFS='?' read -r REQ_PATH get <<<"$REQ_PATH_RAW"
  REQ_PATH="/${REQ_PATH#/}"

  # Url decode get data
  get="$(urldecode "$get")"

  # Split html #
  IFS='#' read -r REQ_PATH _ <<<"$REQ_PATH"
  REQ_QUERY_STRING="$get"
  IFS='&' read -ra data <<<"$get"
  for entry in "${data[@]}"; do
    IFS="=" read -r key val <<<"$entry"
    REQ_QUERIES["$key"]="$val"
  done
}

worker.parse_http_headers() {
  local line _h _v
  # Split headers and put it inside REQ_HEADERS, so it can be reused
  while read -r line; do
    line="${line%%$'\r'}"
    [[ -z "$line" ]] && return
    _h="${line%%:*}"
    REQ_HEADERS["${_h,,}"]="${line#*: }"
  done
}

worker.parse_cookies_data() {
  local -a cookie
  local entry key value
  IFS=';' read -ra cookie <<<"${REQ_HEADERS["cookie"]}"

  for entry in "${cookie[@]}"; do
    IFS='=' read -r key value <<<"$entry"
    REQ_COOKIES["${key# }"]="${value% }"
  done
}

worker.parse_data() {
  local entry
  local content_type="${REQ_HEADERS["content-type"]}"
  # Split POst data into an assoc if is a form, if not create a key raw
  if [[ "$content_type" == "application/x-www-form-urlencoded" ]]; then
    IFS='&' read -rN "${REQ_HEADERS["content-length"]}" -a data
    for entry in "${data[@]}"; do
      entry="${entry%%$'\r'}"
      REQ_POST_DATA["${entry%%=*}"]="${entry#*:}"
    done
  elif [[ "$content_type" == "application/json" ]]; then
    read -rN "${REQ_HEADERS["content-length"]}" data
    REQ_POST_DATA="${data%%$'\r'}"
    ijson_parse_to REQ_POST_DATA <<<"$REQ_POST_DATA"
  else
    read -rN "${REQ_HEADERS["content-length"]}" data
    REQ_POST_DATA="${data%%$'\r'}"
  fi
}

# response building
worker.build_response_headers() {
  printf 'HTTP/1.1 %s\r\n' "${REQ_RESPONSE_HEADERS['status']}"
  unset 'REQ_RESPONSE_HEADERS["status"]'

  # return cookies
  if [[ "${#REQ_COOKIE_TO_SEND[@]}" -gt "0" ]]; then
    for key in "${!REQ_COOKIE_TO_SEND[@]}"; do
      printf 'Set-Cookie: %s=%s;\r\n' "${key}" "${REQ_COOKIE_TO_SEND["${key}"]}"
    done
  fi

  # return headers
  for key in "${!REQ_RESPONSE_HEADERS[@]}"; do
    printf '%s: %s\r\n' "${key,,}" "${REQ_RESPONSE_HEADERS[$key]}"
  done
  printf '\r\n'

}

worker.build_response() {
  REQ_BUILT_RESPONSE=true
  for _fn in "${WORKER_HANDLE_RESPONSE_HOOKS[@]}"; do
    "$_fn" >&299
  done

  local REQ_RESPONSE_CODE="${1:-200}"
  # set status
  REQ_RESPONSE_HEADERS['status']="${WORKER_HTTP_STATUS_CODE[${REQ_RESPONSE_CODE}]}"

  REQ_RESPONSE_HEADERS["content-length"]=$(wc -c /proc/self/fd/299 | awk '{print $1}')
  [[ -z "${REQ_RESPONSE_HEADERS["content-type"]}" ]] && REQ_RESPONSE_HEADERS["content-type"]=$(file -L --mime-type -b /proc/self/fd/299)
  worker.build_response_headers

  cat /proc/self/fd/299 2>/dev/null # outputs content
}

worker.build_error_response() {
  local ERROR_CODE=${1:-500}
  local HTTP_STATUS=${WORKER_HTTP_STATUS_CODE["$ERROR_CODE"]}
  if [ ! -v "WORKER_ERROR_HTML" ]; then
    # long
    printf "<!DOCTYPE html><head><title>${HTTP_STATUS}</title></header><body style=\"background: #090909; color: #FFF; font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh;\"><center><h1 style=\"color: oklch(0.577 0.207 20deg);\">${HTTP_STATUS}</h1><hr><p style=\"color: oklch(0.97 0 0);\">Illusion Web Server</p></center></body>"
  fi
  @respond "$ERROR_CODE"
}

worker.build_error_response.404() {
  # this is make explicitly for compat
  worker.build_error_response 404
}

worker.build_error_response.405() {
  # this is make explicitly for compat
  worker.build_error_response 405
}

worker.process_request_data() {
  # We'll reset them again
  local REQ_METHOD REQ_PATH REQ_PATH_RAW REQ_HTTP_VERSION REQ_QUERY_STRING REQ_PEERADDR
  local -A REQ_HEADERS
  local -A REQ_POST_DATA
  local -A REQ_QUERIES
  local -A REQ_RESPONSE_HEADERS
  local -A REQ_COOKIES
  local -A REQ_COOKIE_TO_SEND

  # ijson REQ_POST_DATA

  # parse http request
  read -r REQ_METHOD REQ_PATH_RAW REQ_HTTP_VERSION
  REQ_HTTP_VERSION="${REQ_HTTP_VERSION%%$'\r'}"

  # get peer ip addr
  REQ_PEERADDR=${SOCAT_PEERADDR:-undefined}

  # parsing request path
  local -A REQ_PATH_PROC
  REQ_PATH="$(printf '%s' "${REQ_PATH_RAW%%\?*}")" # removes query string
  worker.parse_http_headers

  worker.parse_get_data

  worker.parse_cookies_data

  if [[ "${REQ_COOKIES["X-Illusion-Session"]}" == "" ]]; then
    REQ_SESSION_ID="$(uuidgen)"
  else
    REQ_SESSION_ID="${REQ_COOKIES["X-Illusion-Session"]// /_}"
  fi
  REQ_COOKIE_TO_SEND["X-Illusion-Session"]="$REQ_SESSION_ID"

  if ([[ "$REQ_METHOD" == "POST" ]] || [[ "$REQ_METHOD" == "PUT" ]] || [[ "$REQ_METHOD" == "PATCH" ]]) && [[ "${REQ_HEADERS['content-length']}" -gt "0" ]]; then
    worker.parse_data
  fi

  # create a temporary file
  REQ_OUT_PATH="$(mktemp)"
  exec 299<>"$REQ_OUT_PATH"
  rm "$REQ_OUT_PATH" # immediately remove the file
  # fd 299 is open!

  worker.process_path
}

worker.cleanup_request() {
  # closes fd 299
  exec 299>&-
  exec 296>&-
}

worker.handle_call() {
  declare -g REQ_BUILT_RESPONSE=false
  local REQ_FUNCTION="$1"

  # Call "handle" hook if exist
  if [[ "${#WORKER_HANDLE_CALL_HOOKS[@]}" -gt 0 ]]; then
    for _fn in "${WORKER_HANDLE_CALL_HOOKS[@]}"; do
      # calling each of the hook
      "$_fn" 1>&299

      if "$REQ_BUILT_RESPONSE"; then
        cat /proc/self/fd/296 # responds
        return
      fi
    done

    # if never made a response
    "$REQ_FUNCTION" 1>&299
  else
    "$REQ_FUNCTION" 1>&299
  fi

  # check if returned a http response
  if ! "$REQ_BUILT_RESPONSE"; then
    worker.build_response 200 # ok by default
  else
    cat /proc/self/fd/296
  fi
}

# process path to function
# /index.html -> something that calls to get index.html
worker.process_path() {
  # see if path exists
  local -n WORKER_STATIC_ROUTES="WORKER_STATIC_ROUTES_${REQ_METHOD}"
  local -n WORKER_DYNAMIC_ROUTES="WORKER_DYNAMIC_ROUTES_${REQ_METHOD}"

  if [[ "${WORKER_STATIC_ROUTES@a}" != "A" ]] || [[ "${WORKER_DYNAMIC_ROUTES@a}" != "A" ]]; then
    # instantly trigger a 405
    worker.handle_call "worker.build_error_response.405"
    return
  fi

  local REQ_FUNCTION="${WORKER_STATIC_ROUTES["${REQ_PATH}"]}"
  local fn field

  if [[ -z "$REQ_FUNCTION" ]]; then
    for _re in "${!WORKER_DYNAMIC_ROUTES[@]}"; do
      if [[ "$REQ_PATH" =~ ^${_re}$ ]]; then
        IFS=" <=> " read -r fn fields <<<"${WORKER_DYNAMIC_ROUTES["${_re}"]}"
        local i=1                         # 0 is full capture group
        for field in ${fields#$"=> "}; do # bugged => at the start
          export "$field"="${BASH_REMATCH[${i}]}"

          i=$(($i + 1))
        done
        unset i

        # call function
        worker.handle_call "$fn"
        return
      fi
    done
    worker.handle_call "worker.build_error_response.404"
  else
    worker.handle_call "$REQ_FUNCTION"
    return
  fi
}

worker.process_request() {
  trap worker.cleanup_request EXIT
  worker.process_request_data
}

worker.build_to() {
  local OUTPUT="$1"
  cat >"$OUTPUT" <<EOF
#!/bin/bash
# Illusion worker file. DO NOT MODIFY
# Autogenerated by libworker (Illusion) on $(date)
source "${IPREFIX}/libijson.sh"
source "${IPREFIX}/libdeluluclient.sh"
source "${IENTRYPOINT}"
DELULU_AUTHKEY="$DELULU_AUTHKEY"
DELULU_SOCKET="$DELULU_SOCKET"
# MODULE START
EOF

  declare -p "WORKER_HTTP_STATUS_CODE" \
    "WORKER_STATIC_ROUTES_GET" "WORKER_DYNAMIC_ROUTES_GET" \
    "WORKER_STATIC_ROUTES_POST" "WORKER_DYNAMIC_ROUTES_POST" \
    "WORKER_STATIC_ROUTES_PATCH" "WORKER_DYNAMIC_ROUTES_PATCH" \
    "WORKER_STATIC_ROUTES_PUT" "WORKER_DYNAMIC_ROUTES_PUT" \
    "WORKER_STATIC_ROUTES_DELETE" "WORKER_DYNAMIC_ROUTES_DELETE" \
    "WORKER_HANDLE_CALL_HOOKS" "WORKER_HANDLE_RESPONSE_HOOKS" \
    "${WORKER_VARIABLES_TO_EXPORT[@]}" >>"$OUTPUT"

  declare -f "uuidgen" "lower" "urldecode" "worker.parse_get_data" \
    "req.session.set" "req.session.get" "req.session.get_to" "req.session.create" \
    "req.data.get" "req.data.get_to" \
    "req.query.get" "req.query.get_to" \
    "req.response.get" \
    "req.response._openfd" \
    "req.response.set.from_text" "req.response.set.from_args" \
    "req.response.set.from_pipe" "req.response.set.from_variable" \
    "req.response.set.from_stdin" \
    "worker.parse_http_headers" "worker.parse_cookies_data" "worker.parse_data" \
    "worker.build_response_headers" "worker.build_response" "worker.build_error_response" \
    "worker.build_error_response.404" "worker.build_error_response.405" \
    "worker.process_request_data" "worker.cleanup_request" \
    "worker.process_path" "worker.handle_call" \
    "worker.hooks.handle_call" \
    "worker.hooks.handle_response" \
    "${WORKER_FUNCTIONS_TO_EXPORT[@]}" >>"$OUTPUT"
  # process request
  declare -f "worker.process_request" | sed '1,2d;$d;s/^[[:space:]]*//' >>"$OUTPUT"
  echo "# MODULE END" >>"$OUTPUT"
}
