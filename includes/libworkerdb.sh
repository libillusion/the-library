#!/bin/bash
# # The simple and persistant worker database (simple kv)
# # (legacy code)
# [ -z "$ILLUSION_WORKER_DB_FILE" ] &&
#   {
#     export ILLUSION_WORKER_DB_FILE="$(mktemp)"
#     _info "libworkerdb: Loading backend 'basic'"
#     _info "Database initialized at $ILLUSION_WORKER_DB_FILE"
#     chmod 700 "$ILLUSION_WORKER_DB_FILE" # only the current user can see it
#   }
#
# worker.db.eval() {
#   eval "$1"
#   echo "$1" >>"$ILLUSION_WORKER_DB_FILE"
# }
#
# worker.db.fetch() {
#   eval "source \"$ILLUSION_WORKER_DB_FILE\""
# }
#
# worker.db.create() {
#   local DBNAME="${1:-default}"
#   worker.db.eval "declare -gA ${1:-default}"
# }
#
# worker.db.exists() {
#   local DBNAME="wdb_${1:-default}"
#   declare -n _DBNS="$DBNAME"
#   [[ ${_DBNS@a} =~ A ]] && return 0 || return 1
# }
