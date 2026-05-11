# ⬡ FLOW-SN

> A terminal-based workflow runner for Termux on Android and Linux. Build pipelines, connect nodes, execute everything — fully offline, no cloud, no dependencies beyond bash.

**v1.2.5** · Created by [Azaraeth](https://github.com/azaraeth)

---

## What is Flow-SN?

Flow-SN is an open source workflow environment that lets you build, visualize, and execute script pipelines from the terminal. You connect **nodes** to form a graph — Flow-SN walks that graph and runs everything in sequence, printing a live tree as it goes.

Loops and long-running processes (like `ollama serve`) run in the background automatically. Flow-SN never blocks on them — it peeks at the first few lines of output, shows you the PID and log path, then moves on. Short scripts run inline and show their full output.

No internet. No cloud. Just your scripts, running the way you designed them.

---

## Features

- **Fully offline** — no network calls, no external services
- **Multi-language nodes** — bash, python3, node, and ruby out of the box
- **Variable nodes** — store reusable code (assignments, functions, constants) and import them into script nodes with `import <name>`
- **Decision imports** — import decision nodes as callable functions in any supported language
- **Decision nodes** — branch your workflow with true/false conditions in any supported language
- **Fire-and-forget execution** — long-running scripts detach automatically, flow never stalls
- **Loop detection** — looping scripts get a live peek (up to 5 lines) then run detached
- **Persistent background processes** — daemons like `ollama serve` detected and handled gracefully
- **Live tree output** — colored, numbered, branch-art view as the workflow executes
- **Multiple projects** — switch between isolated workflow projects at any time
- **Interactive node editor** — edit node body, subtype, and language inline in the REPL
- **Sortable execution order** — reorder a node's children interactively
- **Export** — export any workflow to a standalone, runnable bash script
- **Cycle guard** — infinite loops in the graph are automatically prevented
- **Root-aware** — detects root/sudo access and works fine without it too

---

## File Overview

| File | Role |
|---|---|
| `flow` | Entry point — backwards-compatible wrapper, calls `flowM.sh` |
| `flowM.sh` | Execution engine, tree view, sort, REPL loop |
| `commandM.sh` | All CRUD commands — add, edit, connect, export, help |
| `UIM` | UI layer — colors, storage helpers, node read/write functions |

Data lives at `~/.flowterm/<project>/` — one `.node` file per node, one `connections` file per project.

---

## Installation

Requires **Termux** (Android) or any **Linux** system with bash. No package installs needed beyond the runtimes you want to use in your script nodes (`python3`, `node`, `ruby`).

```bash
git clone https://github.com/azaraeth/Flow-SN
cd Flow-SN
chmod +x flow flowM.sh
./flow
```

---

## Quick Start

```bash
init mybot
add fetch script bash
setbody fetch echo Hello world
add log text
setbody log Done!
connect start fetch
connect fetch log
connect log end
run
```

```
● 1. start [executing...] ✓ pass
├── 2. fetch [executing...] ✓ pass  [bash]
│   ├ output [fetch]
│   │ Hello world
│   │ ✓ exited · PID: 1234
├── 3. log [executing...] ✓ text
│   ├ output [log]
│   │ Done!
└── 4. end ✓ workflow complete
```

---

## Commands

### Projects

| Command | Description |
|---|---|
| `init [name]` | Create a new project with `start` and `end` nodes |
| `switch <project>` | Switch to an existing project |
| `projects` | List all projects |
| `rmproj <project>` | Delete a project and all its data |

### Nodes

| Command | Description |
|---|---|
| `add <name> [sub] [lang]` | Add a node — sub: `passthrough`, `text`, `script`, `decision`, `variable` |
|| `setbody <name> <content>` | Set a node's body inline |
|| `edit <name>` | Interactively edit a node's subtype, lang, and body |
|| `show <name>` | Inspect a node's full details |
|| `delete <name>` | Remove a node |

### Connections

| Command | Description |
|---|---|
| `connect <from> <to>` | Link two nodes |
| `connect <from> <to> true\|false` | Link a decision node to a branch |
| `disconnect <from> <to>` | Remove a link |
| `sort <node>` | Reorder a node's children interactively |

### Workflow

| Command | Description |
|---|---|
| `list` | List current project's nodes and connections |
| `list --all` | List all projects and their nodes |
| `tree` | Preview the workflow as a tree (no execution) |
| `run` | Execute the workflow |
| `export [file.sh]` | Export workflow to a standalone bash script |
| `reset` | Wipe all nodes and connections in the current project |

---

## Node Types

### `passthrough`
Does nothing — just passes flow from one point to another. Useful as a junction or placeholder.

```bash
add gate passthrough
```

### `text`
Prints a static string when executed.

```bash
add welcome text
setbody welcome Hello from Flow-SN!
```

### `script`
Runs code in the specified language. Supports: `bash`, `sh`, `python`, `python3`, `node`, `nodejs`, `ruby`.

```bash
add fetch script bash
setbody fetch curl -s https://example.com
```

Scripts with a loop (`while`, `for`, `until`) or that are short one-liners are detected as long-running — they detach, show a live peek, then continue. Quick scripts wait for exit and show full output.

### `decision`
Evaluates a condition in any supported language and routes execution based on what it prints. If the script outputs exactly `true` to stdout, the true branch runs. Anything else (or no output) takes the false branch.

```bash
add check decision python3
setbody check
a = 3
b = 0
if a == b:
    print("true")
END

connect check yes_node true
connect check no_node false
```

```
1. check [executing...]  [decision:python3]
│  if a == b: print("true")
└─ [true]  skip
   └─ [yes_node] skipped
└─ [false]  ◀ taken
   └─ 2. no_node [executing...] ✓ text
      ├ output [no_node]
      │ condition was false!
```

A missing branch is silently skipped — no crash, flow continues. Each branch runs as its own independent chain forward.

**Rule:** stdout must be exactly `true` (case-sensitive) to take the true branch.

---

### `variable`

Stores reusable code (assignments, functions, constants, etc.) in a given language. Other script nodes can import it with `import <name>`. When a script node runs, Flow-SN resolves all `import` lines, reads the matching variable node bodies, and prepends them to the script — but only if the variable's language matches the script's language.

```bash
add config variable python3
setbody config
name = "hello"
count = 42
flag = True
END
```

Use it in another script node of the same language. Note: variable bodies are injected as raw code, so you reference the variables directly by name (not as `<node_name>.<var>`):

```bash
add greet script python3
setbody greet
import config
print(name)
print(count + 1)
END
```

At execution time, the script effectively becomes:

```python
# ── import variable: config ──
name = "hello"
count = 42
flag = True
import config
print(name)
print(count + 1)
```

- **Language matching:** If the variable's language doesn't match the script's language, the import is skipped with a comment annotation — no crash.
- **Not found:** If the imported variable doesn't exist, a comment annotation is injected — no crash.
- **Not a workflow step:** Variable nodes are never traversed during `run` or `tree`. They exist purely as reusable code libraries.
- **Editable:** Change a variable's body at any time; all scripts using it see the new values on next run.

---

### Importing decision nodes

Decision nodes can also be imported into script nodes with `import <name>`. When imported, the decision's condition body is wrapped in a callable function so the script can invoke it and branch on the result.

```bash
add is_prod decision python3
setbody is_prod
import os
print("true" if os.getenv("ENV") == "production" else "false")
END
```

Import and use it in a script node of the same language:

```bash
add deploy script python3
setbody deploy
import is_prod
if is_prod():
    print("Deploying to production!")
END
```

At execution time, the decision body is wrapped as a callable function that captures stdout and returns a boolean. For Python the injected code looks like:

```python
# ── import decision: is_prod ──
def is_prod():
    import io, sys
    _old = sys.stdout
    sys.stdout = io.StringIO()
    import os
    print("true" if os.getenv("ENV") == "production" else "false")
    _out = sys.stdout.getvalue().strip()
    sys.stdout = _old
    return _out == "true"
```

The function wraps the decision's original body, captures its stdout (which prints `"true"` or `"false"`), and returns a boolean the caller can use directly.

The same pattern works for all supported languages — the wrapper captures stdout and returns a truthy/falsy value:

| Language | Wrapper style | Call style |
|---|---|---|
| python3 | `def <name>():` captures stdout via `io.StringIO`, returns `bool` | `if <name>():` |
| bash/sh | `<name>() { _out=$( ... ); [[ $_out == "true" ]] && return 0 \|\| return 1; }` | `if <name>; then` |
| node/js | `function <name>() {` captures `process.stdout.write`, returns `boolean` | `if (<name>())` |
| ruby | `def <name>` captures `$stdout` via `StringIO`, returns `bool` | `if <name}` |

- **Language matching:** Same as variables — the decision's language must match the script's language.
- **Not found:** A comment annotation is injected — no crash.
- **Combining imports:** You can import both variable and decision nodes in the same script:
  ```bash
  add deploy script python3
  setbody deploy
  import config
  import is_prod
  if is_prod():
      print(f"Deploying {name} to production!")
  END
  ```
  (Remember: variable bodies are injected raw, so use `name` not `config.name`.)

---

## Sorting Execution Order

Children of a node execute in the order they were connected. To change the order:

```
sort start
```

```
── sort children of [start] ──

  1. fetch
  2. ai
  3. sustain

  enter new order as numbers separated by spaces
  example: 3 1 2

  ▶ 2 3 1

  ✓ sorted children of start:
  1. ai
  2. sustain
  3. fetch
```

---

## Background Logs

Every script node writes its output to a log file you can follow at any time:

```bash
# Script node output
tail -f ~/.flowterm/fetch_bg.log

# Decision node condition evaluation
tail -f ~/.flowterm/check_decision.log
```

For monitoring background runs launched with `runbg`, see [flowmon](https://github.com/azaraeth/Flowmon) — the companion background run manager.

---

## Companion Tool — flowmon

`flowmon` is a dedicated REPL monitor for workflows started with `runbg`. Open it in a second Termux session to watch your background runs live:

```bash
bash flowmon.sh
```

```
ls                          # list all background runs
status <run_id>             # per-node status table
watch  <run_id>             # live auto-refreshing dashboard
logs   <run_id> [node]      # tail logs
stop   <run_id>             # kill a run
clean                       # remove all finished runs
```

---

## Changelog

### v1.2.4
- **sort now shows branch labels** — `[true]` / `[false]` tags are displayed next to each child in the sort prompt so you can see which branch each child belongs to before reordering
- **sort preserves branch tags** — reordering a decision node's children no longer drops the `true`/`false` branch associations (bug fix)
- **list --all now shows branch tags** — the `--all` flag now displays `[true]` / `[false]` labels on decision node connections, matching the behavior of the regular `list` command
- **tree view now shows branch labels** — decision node children in the tree view now display `[true]` / `[false]` tags next to each child arrow
- **runbg uses snapshot isolation** — background runs now read node data and connections from a private snapshot at launch time, so editing nodes while a background run is in progress no longer affects the running workflow
- **export uses portable shebang** — exported workflows now use `#!/usr/bin/env bash` instead of the hardcoded Termux path, so they run on any Linux system (bug fix)
- **node_delete uses exact field matching** — deleting a node no longer risks affecting connections of other nodes with similar names (e.g. deleting "check" would not accidentally affect "mycheck") (bug fix)
- **conn_in uses exact field matching** — same fix as node_delete for the reverse lookup
- **migrate_legacy improved** — migration from the old flat file structure now checks for the `project1/nodes` directory specifically, not just `project1`, preventing skipped migrations
- **conn_out documentation** — added a note that callers should pass `"true"` or `"false"` for decision nodes to avoid mixing branches
- **Banner version updated** — now shows `V1.2.3 OPENSOURCE` to match the actual release version

### v1.2.3
- Root detection on startup — shows `⬡ root access detected` if running as root or with passwordless sudo
- Non-root devices show a friendly compatibility notice
- Script nodes can use `sudo` commands naturally when root is available

### v1.2.2
- Linux compatibility — replaced hardcoded Termux shebangs with `#!/usr/bin/env bash`
- Now runs on any system with bash

### v1.2.1
- Added `decision` node type with true/false conditional branching
- `connect` now accepts an optional `true`/`false` branch argument
- Connections file supports optional 3rd column for branch tags
- `list` and `show` display branch labels on decision connections
- Decision condition evaluation logged to `~/.flowterm/<node-id>_decision.log`
- Added cyan (`CY`) color for decision node highlighting

### v1.2.0
- Initial open source release

---

## License

See [LICENSE](./LICENSE) for details.

---

*Flow-SN — build it, connect it, run it.*
