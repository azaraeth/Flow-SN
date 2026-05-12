# SN-Flow — Terminal Workflow Runner

```
     ███████╗███╗   ██╗      ███████╗██╗      ██████╗ ██╗    ██╗
     ██╔════╝████╗  ██║      ██╔════╝██║     ██╔═══██╗██║    ██║
     ███████╗██╔██╗ ██║█████╗█████╗  ██║     ██║   ██║██║ █╗ ██║
     ╚════██║██║╚██╗██║╚════╝██╔══╝  ██║     ██║   ██║██║███╗██║
     ███████║██║ ╚████║      ██║     ███████╗╚██████╔╝╚███╔███╔╝
     ╚══════╝╚═╝  ╚═══╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝
     V1.2.4 OPENSOURCE
```

> ⬡ **sn-flow** · workflow runner — Created by **Azaraeth(SOLORA-NETWORK)**

SN-Flow is a self-contained, terminal-native workflow builder and runner. Define nodes (scripts, text, decisions, variables, sleep), connect them into a directed graph, and execute them — all from an interactive shell prompt.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [File Structure](#file-structure)
- [Commands](#commands)
  - [Project Management](#project-management)
  - [Node Management](#node-management)
  - [Graph Management](#graph-management)
  - [Execution](#execution)
  - [Utilities](#utilities)
- [Node Types](#node-types)
  - [start](#start-node)
  - [end](#end-node)
  - [command](#command-node)
- [Subtypes](#subtypes)
  - [passthrough](#passthrough)
  - [text](#text)
  - [script](#script)
  - [decision](#decision)
  - [variable](#variable)
  - [sleep](#sleep)
- [Supported Languages](#supported-languages)
- [Import System](#import-system)
- [Background Runs](#background-runs)
- [Data Storage](#data-storage)

---

## Installation

```bash
git clone <repo-url>
cd sn-flow
chmod +x flow flowM.sh commandM.sh UIM
```

Run the interactive REPL:

```bash
./flow
```

---

## Quick Start

```bash
# Start the REPL
./flow

# Inside the REPL:
init mybot
add fetch script bash
setbody fetch echo "Hello from fetch!"
add log text
setbody log "Workflow complete."
add wait sleep 2
connect start fetch
connect fetch wait
connect wait log
connect log end
run
```

---

## File Structure

| File | Role |
|---|---|
| `flow` | Entry point — backwards-compatible wrapper that calls `flowM.sh` |
| `flowM.sh` | Main REPL, execution engine, tree view, background runner |
| `commandM.sh` | All CRUD commands — node/project/connection management |
| `UIM` | Shared library — colors, storage helpers, import resolution |

Data is stored under `~/.flowterm/`.

---

## Commands

### Project Management

---

#### `init`

Create a new project. Automatically creates `start` and `end` nodes.

```
init [name]
```

```bash
init myproject
# ✓  initialized project: myproject
# ·  nodes created: start + end
```

If no name is given, defaults to `project1`.

---

#### `switch`

Switch to a different existing project.

```
switch <project>
```

```bash
switch myproject
# ✓  switched to: myproject
```

---

#### `projects`

List all projects and how many nodes each has.

```
projects
```

```bash
projects
# ── projects ────────────────────────────────
#   myproject             3 nodes  ← current
#   anotherbot            7 nodes
```

---

#### `rmproj`

Delete a project and all its data permanently (prompts for confirmation).

```
rmproj <project>
```

```bash
rmproj anotherbot
#   delete project 'anotherbot' and all its data? [y/N] y
# ✓  deleted project: anotherbot
```

---

#### `reset`

Wipe all nodes and connections in the current project (prompts for confirmation).

```
reset
```

```bash
reset
#   reset project 'myproject'? [y/N] y
# ✓  project 'myproject' reset
```

---

### Node Management

---

#### `add`

Add a new node to the current project.

```
add <name> [subtype] [lang|duration]
```

Subtypes: `passthrough` · `text` · `script` · `decision` · `variable` · `sleep`

```bash
# passthrough (default)
add checkpoint

# text node
add greeting text

# script node
add fetch script bash

# decision node
add check_env decision python3

# variable node
add constants variable bash

# sleep node (2 seconds)
add wait sleep 2
```

---

#### `setbody`

Set the body of a node inline (single line).

```
setbody <name> <content>
```

```bash
# Set a text node's message
setbody greeting Welcome to SN-Flow!

# Set a bash script node
setbody fetch curl -s https://api.example.com/data

# Set a decision node (must print "true" or "false")
setbody check_env [ -f .env ] && echo true || echo false

# Set a sleep duration
setbody wait 5
```

---

#### `edit`

Interactively edit a node's subtype, language, and body. Supports multi-line input — type `END` to finish or `KEEP` to preserve the existing body.

```
edit <name>
```

```bash
edit fetch
# ── edit: fetch ────────────────────────────
#   subtype [passthrough/script/text/decision/variable/sleep] (enter=keep 'script'):
# script
#   lang [bash/python3/node/ruby] (enter=keep 'bash'):
# python3
#   enter body lines, then type END (or KEEP to keep existing):
# import requests
# print(requests.get("https://api.example.com").text)
# END
# ✓  saved: fetch
```

---

#### `show`

Inspect all details of a node — type, subtype, language, connections, imports, and body.

```
show <name>
```

```bash
show fetch
# ── node: fetch ────────────────────────────
#   type     command
#   subtype  script
#   lang     bash
#   imports  constants
#   out      log
#   in       start
# ────────────────────────────────────────────
#   body:
#   │  import constants
#   │  curl -s $BASE_URL
```

---

#### `delete`

Remove a node and all its connections (prompts for confirmation).

```
delete <name>
```

```bash
delete fetch
#   delete 'fetch'? [y/N] y
# ✓  deleted: fetch
```

---

#### `list`

List all nodes and connections in the current project.

```
list
list --all   (or -a)
```

```bash
list
# ── nodes [myproject] ──────────────────────
#   start              start
#   fetch              command          [bash]
#   log                command          [text]
#   end                command

# ── connections [myproject] ────────────────
#   start → fetch
#   fetch → log
#   log   → end

list --all
# ── myproject (current) ────────────────────
#   ...
# ── anotherbot ─────────────────────────────
#   ...
```

---

#### `sort`

Interactively reorder the children of a node. Enter the new order as space-separated numbers.

```
sort <node>
```

```bash
sort start
# ── sort children of [start] ───────────────
#   1. fetch
#   2. validate
#   3. setup
#
#   enter new order as numbers separated by spaces
#   example: 3 1 2
#
# ▶ 3 1 2
# ✓  sorted children of start:
#   1. setup
#   2. fetch
#   3. validate
```

---

### Graph Management

---

#### `connect`

Link two nodes. Decision nodes require a `true` or `false` branch tag.

```
connect <from> <to> [true|false]
```

```bash
# Simple connection
connect start fetch
# ✓  connected: start → fetch

# Decision branches
connect check_env deploy true
connect check_env notify false
# ✓  connected: check_env → deploy  [true]
# ✓  connected: check_env → notify  [false]
```

---

#### `disconnect`

Remove a connection between two nodes.

```
disconnect <from> <to>
```

```bash
disconnect fetch log
# ✓  disconnected: fetch → log
```

---

### Execution

---

#### `run`

Execute the workflow in the foreground. Displays a live tree-style view with per-node timing, colored output, and a connections summary at the end.

```
run
```

```bash
run
# ── run [myproject] ────────────────────────
#
#   ● ┌── 1. start [executing...] ✓ pass
#   │   ├── output [start]
#   │   ├── 2. fetch [executing...] ✓ pass  [bash]
#   │   │   ├── output [fetch]
#   │   │   │  {"status":"ok"}
#   │   │   │  ✓ exited · PID: 12345
#   │   │   │  time: 142ms
#   │   └── 3. log [executing...] ✓ text
#   │       ├── output [log]
#   │       │  Workflow complete.
#   └── 4. end ✓ workflow complete
#
#   total time: 198ms
```

---

#### `runbg`

Launch the workflow fully detached in the background. Each run gets a unique session directory with logs and status files.

```
runbg
```

```bash
runbg
# ── runbg [myproject] ──────────────────────
#
# ✓  workflow launched fully in background
# ·  run ID  : myproject_20250512_143201
# ·  PID     : 98231
# ·  logs    : ~/.flowterm/runs/myproject_20250512_143201
#
# ·  monitor : bash ./flowmon.sh
#              use logs <run_id> and stop <run_id> inside monitor
```

Per-run files:

| File | Contents |
|---|---|
| `meta` | Project name, run ID, start time, PID |
| `run.log` | Top-level execution log |
| `workflow.status` | `RUNNING` · `COMPLETE` · `ERROR` |
| `node_<id>.log` | Per-node stdout/stderr |
| `node_<id>.status` | `PENDING` · `RUNNING` · `DONE` · `ERROR:<code>` |

---

### Utilities

---

#### `tree`

Display the entire workflow as an ASCII tree with node badges, connection arrows, and import counts.

```
tree
```

```bash
tree
# ── workflow tree [myproject] ───────────────
#
#    [start] →fetch
#    │  start the pipeline
#    └─ [fetch] [bash] →check_env
#       │  import constants
#       └─ [check_env] [decision:bash] →deploy →notify
#          └─ [deploy] [bash]
#          └─ [notify] [text]
```

---

#### `export`

Export the entire workflow to a standalone, self-contained bash script. Import directives are resolved and inlined automatically.

```
export [file.sh]
```

```bash
export my_workflow.sh
# ── export → my_workflow.sh ────────────────
# ✓  exported: my_workflow.sh
# ·  run with: bash my_workflow.sh
```

Defaults to `workflow_export.sh` if no filename is given.

---

#### `clear`

Clear the terminal and redisplay the banner and current project info.

```
clear
```

---

#### `help`

Display the full command reference and a quick-start example.

```
help   (also: h  or  ?)
```

---

#### `exit`

Exit the REPL.

```
exit   (also: quit  or  q)
```

---

## Node Types

Every node belongs to one of three top-level types.

### `start` Node

Auto-created by `init`. The entry point of every workflow — execution always begins here. There is exactly one `start` node per project.

```
[start] ──→ [fetch] ──→ [end]
```

### `end` Node

Auto-created by `init`. Execution stops when the traversal reaches `end`. It is never executed itself — it is a sentinel only.

### `command` Node

Every user-created node is a `command` node, distinguished further by its **subtype**.

---

## Subtypes

### `passthrough`

A no-op node. Passes execution directly to its children with no side effects. Useful as a junction or placeholder.

```bash
add checkpoint
connect fetch checkpoint
connect checkpoint log
connect checkpoint notify
```

During `run`, a passthrough node shows `✓ pass` and moves on immediately.

---

### `text`

Outputs a static text message to the terminal during execution.

```bash
add greeting text
setbody greeting Deployment started. Stand by.
connect start greeting
connect greeting fetch
```

Output during `run`:

```
2. greeting [executing...] ✓ text
   ├── output [greeting]
   │  Deployment started. Stand by.
```

---

### `script`

Executes a code snippet in the specified language. Supports `bash`, `python3`, `node`, and `ruby`. Scripts that contain loops are automatically run in the background with live log tailing.

```bash
add fetch script bash
setbody fetch curl -s https://api.example.com/health

add process script python3
setbody process import json; data = {"ok": True}; print(json.dumps(data))

add notify script node
setbody notify console.log("Build", process.env.BUILD_ID, "complete")

add check script ruby
setbody check puts RUBY_VERSION
```

Scripts can reference **variable** nodes using the `import` directive (see [Import System](#import-system)).

---

### `decision`

Evaluates a condition script. The script must print exactly `true` or `false` to stdout. The runner then follows only the matching branch.

```bash
add check_env decision bash
setbody check_env [ -f .env ] && echo true || echo false

connect check_env deploy true
connect check_env abort  false
```

Python3 example:

```bash
add has_data decision python3
setbody has_data import os; print("true" if os.path.exists("data.json") else "false")

connect has_data process true
connect has_data skip    false
```

During `run`, only the taken branch is shown:

```
3. check_env [executing...]  [decision:bash]
   │  true
   │  12ms
   └─ [true]  ◀ taken
      └── 4. deploy [executing...] ✓ pass  [bash]
```

---

### `variable`

Stores reusable code — constants, assignments, or helper functions. Variable nodes are **never executed directly** during a run. They are injected into scripts via `import <name>`.

```bash
add constants variable bash
setbody constants BASE_URL=https://api.example.com API_KEY=secret123

add utils variable python3
setbody utils def greet(name): return f"Hello, {name}!"
```

Use inside a script node:

```bash
add fetch script bash
setbody fetch import constants
# At runtime this becomes:
# BASE_URL=https://api.example.com
# API_KEY=secret123
# curl -s $BASE_URL
```

---

### `sleep`

Pauses workflow execution for a specified number of seconds (supports decimals).

```bash
add wait sleep 2
# or set a duration later:
add pause sleep
setbody pause 0.5

connect fetch wait
connect wait log
```

During `run`:

```
3. wait [executing...] ✓ pass
   ├── output [wait]
   │  sleeping 2s...
   ├── output [wait]
   │  ✓ done sleeping (2s)
   │  2.00s
```

---

## Supported Languages

| Token | Runtime | Notes |
|---|---|---|
| `bash` / `sh` | Bash | Default for most nodes |
| `python` / `python3` | Python 3 | Use `-u` flag (unbuffered) |
| `node` / `nodejs` / `js` | Node.js | Uses `node -e` |
| `ruby` | Ruby | Uses `ruby -e` |

Specify the language when creating a `script`, `decision`, or `variable` node:

```bash
add myscript script python3
add mycheck  decision node
add myconsts variable ruby
```

---

## Import System

The `import` directive lets script, decision, and variable nodes share code without duplication.

**Variable node** — body is injected raw:

```bash
# variable node "config"
BASE_URL=https://api.example.com
TIMEOUT=30

# script node "fetch" using it
import config
curl -s --max-time $TIMEOUT $BASE_URL/status
```

**Decision node** — body is wrapped in a callable function named after the node:

```bash
# decision node "is_online" (bash)
curl -sf https://api.example.com/ping >/dev/null && echo true || echo false

# script node that calls it
import is_online
if is_online; then
  echo "API is up"
fi
```

Language-aware wrappers are generated automatically for bash, python3, node, and ruby. If the imported node's language doesn't match the importing script's language, the import is skipped with a comment explaining the mismatch.

---

## Background Runs

`runbg` launches the workflow in a fully detached subprocess. State is snapshotted at launch time so live edits don't affect the running session.

Each run is logged under:

```
~/.flowterm/runs/<proj>_<timestamp>/
  meta                  — proj, run_id, started, pid
  run.log               — top-level execution log
  workflow.status       — RUNNING | COMPLETE | ERROR
  node_<id>.log         — per-node stdout + stderr
  node_<id>.status      — PENDING | RUNNING | DONE | ERROR:<code>
  connections.snap      — connection snapshot at launch
  snapshot_nodes/       — node file snapshots at launch
```

Use `flowmon.sh` to monitor running sessions:

```bash
bash flowmon.sh
# inside monitor:
# logs <run_id>    — tail the run log
# stop <run_id>    — kill the background process
```

---

## Data Storage

All project data lives in `~/.flowterm/`:

```
~/.flowterm/
  .projects                    — list of all project names
  <project>/
    nodes/
      start.node               — node file (type / subtype / lang / body)
      end.node
      <name>.node
    connections                — space-separated: "from to [branch]"
  runs/
    .registry                  — list of all background run IDs
    <run_id>/                  — per-run session directory
```

Node files use a simple 3-line header format:

```
<type>          ← line 1: start | end | command
<subtype>       ← line 2: passthrough | text | script | decision | variable | sleep
<lang>          ← line 3: bash | python3 | node | ruby | - (if not applicable)
<body...>       ← remaining lines: the node's content
```
