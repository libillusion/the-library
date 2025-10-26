#1/bin/sh
# The Illusion Library
# Default values
IPRODNAME="Illusion"
IPRODVER="valpha0"
IWEB_ADDRESS="0.0.0.0:8080"

source libillusionext.sh
source libworkerdb.sh

# Components
# log -> logging components
# web -> the webserver

function web.selfcheck() {
  _log "Running selfcheck..."

  _log "Selfcheck OK, proceeding..."
}

# web.init
function web.init::help() {
  echo "You're using $IPRODNAME $IPRODVER."
  cat <<EOF
All values are separated by --key=value OR -k=v
Available options:
  -a | --address      | The address of the server.
EOF
}

function web.init() {
  while getopts ":vf:" opt; do
    for i in "$@"; do
      case $1 in
      -a=* | --address=*)
        IWEB_ADDRESS="${i#*=}"
        shift
        ;;
      *)
        web.init::help
        exit
        ;;
      esac
    done
  done

  web.selfcheck

  # create worker routes
  set -A WORKER_ROUTES
  export WORKER_ROUTES

}
