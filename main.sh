#!/bin/bash
source includes/lib.sh

function index() {
  local this_key this_value
  req.session.get_to this_key this_key
  req.session.get_to this_value this_value
  req.session.set "test" "\$(echo whoops >/dev/stderr)"

  if [[ -z "$this_key" ]]; then
    @respond 200 json <<EOF
{
  "message": "You haven't set it up yet."
}
EOF
  fi

  @respond 200 json <<EOF
{
  "this_key": "$this_key"
  "this_value": "$this_value"
}
EOF
}

function test_post() {
  req.data.get_to "this_key" "key"
  req.data.get_to "this_value" "value"
  req.session.set "this_key" "$this_key"
  req.session.set "this_value" "$this_value"
  @respond 200 json <<EOF
{
  "message": "All operations completed successfully."
}
EOF
  return
}

function disposition_test() {
  # @respond 200 file jsonbench.py <./jsonbench.py
  @respond 200 disposition-inline jsonbench.py <./jsonbench.py
  return
}

illusion.server.init() {
  export fat_fuck="fat fuck $RANDOM"
}

worker.hooks.handle_call() {
  @log "$REQ_PEERADDR | $REQ_METHOD $REQ_PATH $REQ_FUNCTION"
}

worker.hooks.handle_response() {
  @set_cookie "X-Something-IThink" "lool123"
}

illusion.server \
  --get="/->index" \
  --get="/users/[user_id]/posts/[post_id]->index" \
  --post="/->test_post" \
  --get="/file.py/->disposition_test" \
  --enable-plugins-I-UNDERSTAND-THE-CONSEQUENCES \
  --plugin="./plugins/test.ilp.sh"
