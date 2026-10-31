---
name: yen-mcp
description: Use when you read, check or change a Yen fleet through its MCP server (the yen_* tools). It gives the order of calls, the shape of every answer, how to stage a change before you write it, and what to do with each refusal. Do not use it to edit fleet files without staging, or for Nix questions that no yen_* tool answers.
---

# yen-mcp: work on a Yen fleet through its MCP server

The server answers queries on the fleet in its directory. Every answer is data. Nothing is applied: you read,
you stage, and only then you write files.

## Start the server

From the fleet directory: `nix run github:vic/yen?dir=mcp`. The server serves the fleet in its working directory, so
start it there. In an MCP client config:

```json
{ "mcpServers": { "yen": { "command": "nix", "args": [ "run", "github:vic/yen?dir=mcp" ] } } }
```

`YEN_TIMEOUT` sets the seconds per call (default 120).

## Read every answer the same way

The tool result is one text block that holds JSON:

- `{ "complete": true, "result": … }`: the answer.
- `{ "complete": false, "error": "timeout" }`: the evaluation did not finish. This is not an empty answer. Ask a
  narrower question, or raise `YEN_TIMEOUT`.
- `isError: true` with `{ "complete": false, "error": "…" }`: the evaluation failed. Read the error line.

An error record in a result has `code`, `path`, `got`, `want`, `fix` and, for typos, `near`. Use `fix` and `near`.

## Facts and ids

- A scope id is a path from the root: `fleet:main/environment:prod/host:lb`.
- A fact and an atom are lists: `["kind","host",ID]`, `["has",ASPECT,ID]`, `["val",FIELD,ID,VALUE]`,
  `["ref",FIELD,ID,KIND,NAME]`, `["edge",SINK,FROM,TO]`, `["instance",ID,KIND,NAME]`, `["parent",ID,PARENT]`.
- A violation is an atom that starts with `"bad"`, for example `["bad","attic-on-mac","fleet:main/…/mac:studio"]`.
  Give atoms to tools as JSON arrays, never as strings.

## The order of calls

1. **Learn the fleet.** `yen_schema`: its kinds, fields, aspects and invariants. Do this first, every session.
2. **Check it.** `yen_check`. The fleet is good only when all of these hold:
   - `ok` is true;
   - `violations`, `incomplete` and `opaque` are empty;
   - `certified` is true.

   An `incomplete` atom is undecided, and an `opaque` field is one a rule cannot see. Neither is a pass.
3. **Explain what you see.**
   - `yen_context` with a scope id: one scope, its parent, children, aspects, elements and errors.
   - `yen_explain` with an aspect and a scope: why the aspect is active, inactive or undefined there.
   - `yen_why_not` with an atom: whether it holds, and the rules for and against it.
   - `yen_declared_in` with a declaration path: the files that answer it.
   - `yen_impact` with a scope id: the scopes its elements reach, by depth.
   - `yen_errors`, optionally with one `code`.
   - `yen_labels`: the trust of each aspect's files. With `floor`, the edges below that trust.
4. **Use stored queries.** `yen_queries` lists them with their parameters and types. `yen_ask` runs one with `name`
   and `args`. A ref parameter is its identity: `{"kind":"host","name":"lb"}` an instance, `{"kind":"host"}` a kind,
   `{"aspect":"attic"}` an aspect. A name string where a ref belongs comes back as an error record (`ref`), and so
   does a missing parameter (`missing-param`): never an evaluation failure.
5. **Stage every change before you write it.**
   - `yen_program` with a list of ops is the safest form of a change. It gives `valid`, `errors`, `ok`,
     `violations` and the diff.
   - `yen_stage` with a `change` (a Yen module as JSON) gives `ok`, `errors`, `violations`, `incomplete`, `diff`,
     `refused` and the change's `sha`.
   - Write the change to the fleet's files only when `ok` is true. Then call `yen_check` again.
6. **Export only when asked.** `yen_export` gives the whole fleet as sorted N-Triples with a sha256. It is large.

## Refusals

- `class = "authority"` (`outside-grant`, `law-change`, `rejected`): no edit by you can fix it. Do not retry with
  changes. Tell the owner what you wanted to change and why. A change never declares `invariants`, `relations`,
  `labels` or `flake`; those are the owner's.
- `class = "fixable"`: fix what the record says (`fix`, `near`, `want`) and stage again.
- A new violation: the change breaks a rule across machines. Change the change, not the rule.

## Never

- Never say the fleet is fine without a `yen_check` that meets every condition in step 2.
- Never treat a timeout, an empty list from a failed call, or an `incomplete` answer as a pass.
- Never write to the fleet's files before a staged `ok = true`.
