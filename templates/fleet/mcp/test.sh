#!/usr/bin/env bash
# Drives yen-mcp.sh with JSON-RPC lines. Run from anywhere; each call is capped at 300 s.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SRV=${YEN_MCP_SERVER:-$HERE/yen-mcp.sh}
fails=0

rpc() { printf '%s\n' "$1" | timeout -k 5 300 "$SRV"; }
call() { rpc "$(jq -cn --arg n "$1" --argjson a "$2" '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$n,arguments:$a}}')"; }
text() { jq -c '.result.content[0].text | fromjson'; } # the wrapped { complete, result | error }
check() { # name jq-filter input-json
  if jq -e "$2" <<<"$3" >/dev/null 2>&1; then echo "PASS $1"; else echo "FAIL $1: got $(head -c 400 <<<"$3")"; fails=$((fails + 1)); fi
}

out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check initialize '.result.serverInfo.name == "yen-mcp"' "$out"

out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
check tools-list '(.result.tools | map(.name) | sort) == ["yen_ask","yen_check","yen_context","yen_declared_in","yen_errors","yen_explain","yen_export","yen_impact","yen_labels","yen_program","yen_queries","yen_schema","yen_stage","yen_why_not"]' "$out"

out=$(call yen_schema '{}' | text)
check schema '.complete == true and (.result.kinds | has("host"))' "$out"

out=$(call yen_context '{"id":"fleet:mian"}' | text)
check context-unknown '.result.code == "unknown-scope" and (.result.near | length > 0)' "$out"

out=$(call yen_errors '{}' | text)
check errors-list '.complete == true and (.result | type == "array")' "$out"

out=$(call yen_stage '{"change":{"yen":{"aspects":{"attic":{"at":[{"kind":"mac","name":"studio"}]}}}}}' | text)
check stage-attic '.result.ok == false and (.result.violations | map(contains("attic-on-mac")) | any)' "$out"

out=$(call yen_queries '{}' | text)
check queries-freeport '.result.freePort.required == ["host"]' "$out"

out=$(call yen_ask '{"name":"freePort","args":{"host":"lb"}}' | text)
check ask-freeport '.result.port == 8083' "$out"

out=$(call yen_ask '{"name":"freePort","args":{}}' | text)
check ask-missing-param '.result.code == "missing-param"' "$out"

out=$(call yen_impact '{"id":"fleet:main/environment:prod/host:lb","hops":1}' | text)
check impact-reached '(.result.reached | length) > 0' "$out"

out=$(call yen_impact '{"id":"fleet:main/environment:prod/host:lb","sinks":["nope"]}' | text)
check impact-unknown-sink '.result.code == "unknown-sink"' "$out"

out=$(call yen_labels '{"floor":3}' | text)
check labels-floor '(.result.floor | length > 0 and all(.trust == 1)) and (.result.labels | type == "object")' "$out"

out=$(call yen_why_not '{"atom":"bad:attic-on-mac:fleet:main/environment:staging/mac:studio"}' | text)
check why-not-holds-false '.result.holds == false' "$out"

out=$(call yen_program '{"program":[{"op":"place","aspect":"attic","kind":"mac","name":"studio"}]}' | text)
check program-violation '.result.ok == false and (.result.violations | map(contains("attic-on-mac")) | any)' "$out"

out=$(call yen_program '{"program":[{"op":"plac"}]}' | text)
check program-invalid '.result.valid == false and .result.errors[0].near == ["place"]' "$out"

# a timeout no evaluation can meet (1 ms): the timeout path, without racing the machine's speed
out=$(YEN_TIMEOUT=0.001 call yen_export '{}' | text)
check export-timeout '.complete == false and .error == "timeout"' "$out"


out=$(call yen_export '{}' | text)
check export-full '.complete == true and (.result.sha256 | length == 64) and (.result.count > 0)' "$out"

out=$(call yen_context '{}')
check eval-error '.result.isError == true and (.result.content[0].text | fromjson | .complete == false and (.error | length > 0))' "$out"

# the flake app: `nix run .#yen-mcp` from the fleet directory (set YEN_MCP_SKIP_APP=1 to skip)
if [ -z "${YEN_MCP_SKIP_APP:-}" ]; then
  out=$(cd "$HERE/.." && printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"yen_context","arguments":{"id":"fleet:main/environment:lab/host:app-1","maxEdges":2}}}' \
    | timeout -k 5 600 nix run "path:$(git rev-parse --show-toplevel)?dir=templates/fleet#yen-mcp" 2>/dev/null)
  check flake-app '.result.content[0].text | fromjson | .complete == true and .result.kind == "host" and .result.given.truncated.shown == 2' "$out"
fi
[ "$fails" -eq 0 ]
