#1/bin/sh
# The Illusion Library
export IPREFIX=$(realpath $(dirname ${BASH_SOURCE[0]}))
illusion.server() { true; } # placeholder function
"$ILLUSION_IS_EXPORTED" 2>/dev/null && {
  source "${IPREFIX}/libworkerext.sh"
  return
}

# Exports
# Default values
IPRODNAME="Illusion"
IPRODVER="AlphaZero"
IBACKEND="socat"
IADDRESS="0.0.0.0:8080"
ICLEANUP_CMDS=("$(trap -P EXIT)" "$(trap -P SIGINT)" "$(trap -P SIGTERM)")
IENTRYPOINT="$(realpath "$0")"
export ILLUSION_IS_EXPORTED=true

# Program values
ILLUSION_ENABLE_PLUGINS=false
ILLUSION_PLUGINS=()
ILLUSION_PLUGIN_NAMES=()

declare -Ag WORKER_STATIC_ROUTES_GET
declare -Ag WORKER_STATIC_ROUTES_POST
declare -Ag WORKER_STATIC_ROUTES_PUT
declare -Ag WORKER_STATIC_ROUTES_PATCH
declare -Ag WORKER_STATIC_ROUTES_DELETE

declare -Ag WORKER_DYNAMIC_ROUTES_GET
declare -Ag WORKER_DYNAMIC_ROUTES_POST
declare -Ag WORKER_DYNAMIC_ROUTES_PUT
declare -Ag WORKER_DYNAMIC_ROUTES_PATCH
declare -Ag WORKER_DYNAMIC_ROUTES_DELETE

export ITMPDIR="$(mktemp -d)"
source ${IPREFIX}/librice.sh
source ${IPREFIX}/libworker.sh
source ${IPREFIX}/libdeluluserver.sh
source ${IPREFIX}/libdeluluclient.sh

# Styling
function illusion.logo() {
  # It's only purpose to print the logo.
  echo
  echo "\$\$\$\$\$\$\\ \$\$\\ \$\$\\                     \$\$\\                     "
  echo "\\_\$\$  _|\$\$ |\$\$ |                    \\__|                    "
  echo "  \$\$ |  \$\$ |\$\$ |\$\$\\   \$\$\\  \$\$\$\$\$\$\$\\ \$\$\\  \$\$\$\$\$\$\\  \$\$\$\$\$\$\$\\  "
  echo "  \$\$ |  \$\$ |\$\$ |\$\$ |  \$\$ |\$\$  _____|\$\$ |\$\$  __\$\$\\ \$\$  __\$\$\\ "
  echo "  \$\$ |  \$\$ |\$\$ |\$\$ |  \$\$ |\\\$\$\$\$\$\$\\  \$\$ |\$\$ /  \$\$ |\$\$ |  \$\$ |"
  echo "  \$\$ |  \$\$ |\$\$ |\$\$ |  \$\$ | \\____\$\$\\ \$\$ |\$\$ |  \$\$ |\$\$ |  \$\$ |"
  echo "\$\$\$\$\$\$\\ \$\$ |\$\$ |\\\$\$\$\$\$\$  |\$\$\$\$\$\$\$  |\$\$ |\\\$\$\$\$\$\$  |\$\$ |  \$\$ |"
  echo "\\______|\\__|\\__| \\______/ \\_______/ \\__| \\______/ \\__|  \\__|"
  echo "  the whatever web application framework out of my bedroom"
  echo
}

# Components
# log -> logging components
# illusion.-> the webserver

function illusion.selfcheck() {
  _trace "Running selfcheck..."

  [ ! -f "$IPREFIX/libijson.sh" ] && raise MISSINGLIB "libijson.sh"
  [ ! -f "$IPREFIX/libworkerext.sh" ] && raise MISSINGLIB "libworkerext.sh"
  [ ! -f "$IPREFIX/libworkerrequest.sh" ] && raise MISSINGLIB "libworkerrequest.sh"
  [ ! -f "$IPREFIX/libdeluluserver.sh" ] && raise MISSINGLIB "libdeluluserver.sh"

  _trace "Selfcheck OK, proceeding..."
}

# illusion.cleanup
function illusion.cleanup() {
  for cmd in "${ICLEANUP_CMDS[@]}"; do
    eval "$cmd"
  done
  rm -rf "$ITMPDIR"
  kill "$DELULU_SERVERPID"
  exec 298>&-
  exit 0
}

# routes handling
function illusion.routes.add_dynamic() {
  local from_route="$1" to_function="$2" req_method="$3"
  local GENERATED_REGEX SLUG_VARIABLES

  # get the slug variables
  SLUG_VARIABLES=$(echo "$from_route" | grep -oP '\[\K[^]]+(?=\])' | tr '\n' ' ' | sed 's/,$//')
  SLUG_VARIABLES="${SLUG_VARIABLES% }" # remove trailing space

  # generate matching regex
  GENERATED_REGEX=$(echo "$from_route" | sed -e 's#\[[^]]*\]#([^/]+)#g')
  GENERATED_REGEX="${GENERATED_REGEX%/}/?"

  declare -n WORKER_DYNAMIC_ROUTES="WORKER_DYNAMIC_ROUTES_${req_method}"

  WORKER_DYNAMIC_ROUTES["$GENERATED_REGEX"]="$to_function <=> $SLUG_VARIABLES"
}

function illusion.routes.add_static() {
  local from_route="$1" to_function="$2" req_method="$3"
  declare -n WORKER_STATIC_ROUTES="WORKER_STATIC_ROUTES_${req_method}"
  declare -n WORKER_DYNAMIC_ROUTES="WORKER_DYNAMIC_ROUTES_${req_method}"
  WORKER_STATIC_ROUTES["$from_route"]="$to_function"
}

function illusion.routes.add() {
  local from_route="$1" to_function="$2" req_method="$3"
  to_function=$(echo "$to_function" | sed 's:/*$::') # remove trailing routes
  from_route="${from_route%/}"
  [ -z "$from_route" ] && from_route="/"

  # check if function exists
  if ! declare -fF "$to_function" >/dev/null; then
    raise INVALIDCONF "Function $to_function does not exist (${req_method} route from ${from_route})"
  fi

  # check if url is dynamic
  if [[ "$from_route" =~ \[[^/]+\] ]]; then
    illusion.routes.add_dynamic "$from_route" "$to_function" "$req_method"
    _debug "Added dynamic ${req_method} route from" "$from_route" to "$to_function"
  else
    illusion.routes.add_static "$from_route" "$to_function" "$req_method"
    _debug "Added static ${req_method} route from" "$from_route" to "$to_function"
  fi
}

# illusion.plugins
function illusion.plugin.load() {
  # load "$1"
  local pluginsrc="$1"
  if [ ! -f "$pluginsrc" ]; then
    raise MISSINGLIB "Plugin not found: $pluginsrc"
  fi
  eval "$(
    source "$pluginsrc" || return # warning: code execution!
    local _nsyms=0 _ifn_prefix="${ILLUSION_PLUGIN["functions_prefix"]}" _ivar_prefix="${ILLUSION_PLUGIN["variables_prefix"]}"

    # only export the necessary functions
    for _var in $(declare -g | awk '{print $3}' | grep "^${_ivar_prefix}"); do
      declare -g "$_var"
      _nsyms=$(($_nsyms + 1))
    done
    for _fn in $(declare -F | awk '{print $3}' | grep "^${_ifn_prefix}."); do
      declare -f "$_fn"
      _nsyms=$(($_nsyms + 1))
    done
    printf '_nsyms="%q"; ' "$_nsyms"
    printf '_ifn_prefix="%q"; ' "$_ifn_prefix"
    printf '_ivar_prefix="%q"; ' "$_ivar_prefix"
    printf 'ILLUSION_PLUGIN_NAMES+=("%s")' "${ILLUSION_PLUGIN["name"]}"
  )"
  # add it to worker
  worker.export.add_fn.with_prefix "$_ifn_prefix"
  worker.export.add_var.with_prefix "$_ivar_prefix"
  _debug "Loaded plugin ${ILLUSION_PLUGINS[@]} ($_nsyms symbol$(_add_s _nsyms))"
}

# illusion.init
function illusion.init::help() {
  echo "You're using $IPRODNAME $IPRODVER."
  cat <<EOF
All values are separated by --key=value OR -k=v
Available options:
  -a | --address  <addr>        | The address of the server. (default: 0.0.0.0:8080)
  -b | --backend  <binary>      | Specify backend (socat, ncat) (default: socat)
  -l | --plugin   <path>        | Add a plugin

Server Routing:
  --option="[path]->[function]"

  [ argument ]                  [ request method ]
  -g | --get                    | GET
  -p | --post                   | POST
  -h | --patch                  | PATCH
  -t | --put                    | PUT
  -d | --delete                 | DELETE
  *Dynamic paths has slugs covered by "[]"
   For example, "/path/to/[slug]".
  
  Example usage:
  index() { print "Hello World!"; @return 200; }
  illusion.server --get="/->index"
  => Any request at "/" will call function "index".
EOF
}

function illusion.server() {
  # get start time
  local bench_start=$(date +%s%N)

  # create worker routes
  local IROUTE IHOST IPORT
  illusion.logo
  illusion.selfcheck

  while getopts ":vf:" opt; do
    for i in "$@"; do
      case $1 in
      -a=* | --address=*)
        IADDRESS="${i#*=}"
        shift
        ;;
      -b=* | --backend=*)
        IBACKEND="${i#*=}"
        shift
        ;;
      -l=* | --plugin=*)
        ILLUSION_PLUGINS+="${i#*=}"
        shift
        ;;
      --enable-plugins-I-UNDERSTAND-THE-CONSEQUENCES)
        ILLUSION_ENABLE_PLUGINS=true
        shift
        ;;
      -g=* | --get=*)
        IROUTE="${i#*=}"
        IFS="->" read -r ROUTE_FROM ROUTE_TO <<<"$IROUTE"
        ROUTE_TO="${ROUTE_TO#>}"
        illusion.routes.add "$ROUTE_FROM" "$ROUTE_TO" "GET"
        shift
        ;;
      -p=* | --post=*)
        IROUTE="${i#*=}"
        IFS="->" read -r ROUTE_FROM ROUTE_TO <<<"$IROUTE"
        ROUTE_TO="${ROUTE_TO#>}"
        illusion.routes.add "$ROUTE_FROM" "$ROUTE_TO" "POST"
        shift
        ;;
      *)
        echo "Invalid argument: $i"
        illusion.init::help
        exit
        ;;
      esac
    done
  done

  # check if plugins is enabled
  if [[ "${#ILLUSION_PLUGINS}" -gt "0" ]] && ! $ILLUSION_ENABLE_PLUGINS; then
    echo
    echo -e "${CBYellow}======================= WARNING =======================${CReset}"
    echo -e "I see you're trying to add plugins. It has ${CBRed}risks${CReset}."
    echo -e "${CBGreen}You MUST ONLY enable plugins YOU TRUST.${CReset}"
    echo -e "Loading unknown plugins allows ${CBRed}malicious code execution${CReset}."
    echo -e "${CBYellow}=======================================================${CReset}"
    echo -e "To disable this prompt, add argument \"--enable-plugins-I-UNDERSTAND-THE-CONSEQUENCES\"."

    read -p "Continue? (it may harm your device!) (y/n): " _continue_prompt
    [[ "${_continue_prompt[0],,}" != "y" ]] && exit 1
  fi

  # load plugins
  for _plugin in "${ILLUSION_PLUGINS[@]}"; do
    illusion.plugin.load "$_plugin"
  done
  worker.hooks.load # find hooks
  _info "Loaded ${#ILLUSION_PLUGINS[@]} plugin$(_add_s ILLUSION_PLUGINS): $(for _name in "${ILLUSION_PLUGIN_NAMES[@]}"; do printf '"%s" ' "$_name"; done)"

  # initialize delulu server
  declare -g DELULU_AUTHKEY="$(cat /dev/urandom | tr -dC A-Za-z0-9 | head -c 64)"
  declare -g DELULU_SOCKET="/tmp/tmp.$(uuidgen)"
  delulu.server \
    --socket="$DELULU_SOCKET" \
    --authkey="$DELULU_AUTHKEY" &>/dev/null &
  DELULU_SERVERPID=$?
  _info "Initialized Delulu in-memory database server"

  # build worker
  local BUILD_TARGET_FAKE="$(mktemp)"
  rm "$BUILD_TARGET_FAKE"
  exec 298<>"$BUILD_TARGET_FAKE"
  worker.build_to "/proc/self/fd/298"

  # run initialization (if exist)
  declare -F illusion.server.init &>/dev/null && illusion.server.init

  # get address
  IFS=":" read -r IHOST IPORT <<<"$IADDRESS"
  # This will copy worker's internal files to worker.sh
  # Only turn on for debugging!
  # cat </proc/self/fd/298 >worker.sh

  _welcometo "$IPRODNAME $IPRODVER"
  [ "$RANDOM" == "13579" ] && _warn "not my fault but fuck you"
  _info "Initialized in ${CBCyan}$(awk "BEGIN { print $(($(date +%s%N) - $bench_start)) / 1000000 }")${CReset} ms."
  unset bench_start
  _info "Your webserver is available at ${CBGreen}http://${IADDRESS}${CReset}"

  # run actual ws stuff here
  socat TCP-LISTEN:"${IPORT}",bind="${IHOST}",reuseaddr,fork EXEC:"/usr/bin/env bash /proc/self/fd/298"
}

trap illusion.cleanup SIGINT EXIT SIGTERM
