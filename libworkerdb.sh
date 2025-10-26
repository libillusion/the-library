#!/bin/bash
# The simple and persistant worker database (simple kv)
[ -z "$ILLUSION_WORKER_DB_FILE" ] &&
  {
    export ILLUSION_WORKER_DB_FILE="$(mktemp)"
    chmod 700 "$ILLUSION_WORKER_DB_FILE" # only the current user can see it
  }

worker.db.eval() {
  eval "$1"
  echo "$1" >>"$ILLUSION_WORKER_DB_FILE"
}

worker.db.fetch() {
  source "$ILLUSION_WORKER_DB_FILE"
}

worker.db.create() {
  local DBNAME="wdb_${1:-default}"
  worker.db.eval "declare -gA wdb_${1:-default}" &&
    _log "Created database ${DBNAME}!"
}
