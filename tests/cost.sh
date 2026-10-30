#!/usr/bin/env bash
# Cost oracles: the memos are behavior an eval cannot see, so these bound Nix's own counters (NIX_SHOW_STATS).
#   aspect-ref memo: 30 levels of diamonds; without the memo it is 2^30 reads (a timeout counts as a failure)
#   reduction memo : 150 hosts read one costly sink; without the memo each read reduces again (~n^2)
#   scale          : 400 and 800 services under three rules across machines, checked and certified
# Run from the repository root: bash tests/cost.sh   (each case capped at 30 s, then killed 5 s later: an exponential eval ignores SIGTERM)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
bound() { # name expr max-function-calls
  if NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$tmp/$1.json" timeout -k 5 30 nix-instantiate --eval --strict -E "$2" >/dev/null 2>"$tmp/$1.err"; then
    calls=$(jq '.nrFunctionCalls' "$tmp/$1.json"); thunks=$(jq '.nrThunks' "$tmp/$1.json")
    if [ "$calls" -le "$3" ]; then echo "PASS $1 calls=$calls thunks=$thunks (max $3)"; else echo "FAIL $1 calls=$calls thunks=$thunks (max $3)"; fails=$((fails + 1)); fi
  else echo "FAIL $1 (exit $?, timeout or error)"; fails=$((fails + 1)); fi
}
bound aspect-ref-memo 'import ./tests/cost/diamond.nix { k = 30; }' 200000
bound reduction-memo 'import ./tests/cost/fanin.nix { n = 150; }' 200000
# the scale oracle (.35): every rule over 400 and 800 services, checked and certified; near-linear (before the join
# index, the smallest-bucket pick and rules grouped by head, 400 services took 311M calls)
bound scale-400-services '(import ./bench/scale.nix { n = 100; hostCount = 100; }).check.certified' 6000000
bound scale-800-services '(import ./bench/scale.nix { n = 100; hostCount = 200; }).check.certified' 13000000
exit $fails
