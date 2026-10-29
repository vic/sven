#!/usr/bin/env bash
# run.sh BODY DIR: the nix blocks of an issue body, evaluated as one fleet. Writes DIR/comment.md. Run from the repo root.
# Pure and restricted (--restrict-eval): a block reads nothing outside yen, nixpkgs and its own blocks, within 120 s.
set -eu
body=$1 dir=$2 # BODY - : read the issue body from $ISSUE_BODY (CI passes it so, never through the shell)
if [ "$body" = - ]; then body=$(mktemp); printf "%s" "$ISSUE_BODY" >"$body"; fi
mkdir -p "$dir"
bash docs/issue/extract.sh "$body" "$dir/blocks"
np=$(nix flake prefetch --json "$(jq -r .nodes.nixpkgs.locked.url docs/flake.lock)" | jq -r .storePath)
set +e
timeout 120 nix-instantiate --eval --strict --json --restrict-eval \
  -I yen="$PWD" -I nixpkgs="$np" -I blocks="$dir/blocks" \
  --expr 'import ./docs/issue/eval.nix { yen = <yen>; nixpkgs = <nixpkgs>; blocks = <blocks>; }' \
  >"$dir/out.json" 2>"$dir/err.txt"
rc=$?
set -e
{
  echo "yen evaluated the \`nix\` blocks of this issue as one fleet ([docs/issue/eval.nix](https://github.com/vic/yen/blob/main/docs/issue/eval.nix), yen at ${GITHUB_SHA:-local})."
  echo
  if [ "$rc" = 0 ]; then
    echo '```json'
    jq . "$dir/out.json"
  else
    echo "Evaluation failed (exit $rc):"
    echo
    echo '```text'
    grep -v '^warning' "$dir/err.txt" | tail -40
  fi
  echo '```'
} >"$dir/comment.md"
cat "$dir/comment.md"
