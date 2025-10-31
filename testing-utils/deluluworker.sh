#!/bin/bash
echo ">>> Extracting credentials from worker..."
eval "$(cat worker.sh | sed -n '7,8p')"
[ -z "$DELULU_AUTHKEY" ] && {
  echo "Cannot extract worker database credentials."
  exit 1
} || echo "Extracted DELULU_AUTHKEY and DELULU_SOCKET."
export DELULU_AUTHKEY DELULU_SOCKET
[ -f testing-utils/delulucli.sh ] && source testing-utils/delulucli.sh
[ -f delulucli ] && source delulucli.sh
