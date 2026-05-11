# FLOW-SN

> **Terminal-native workflow automation.** Build, connect, and execute node-based pipelines entirely from your shell.

**Version:** v1.2.4 · **Author:** Azaraeth (Solora Network)

---

## Table of Contents

- [Overview](#overview)
- [Data Layout](#data-layout)
- [UIM — UI Manager](#uim--ui-manager)
  - [Color Variables](#color-variables)
  - [Storage & Paths](#storage--paths)
  - [Node File Format](#node-file-format)
  - [Node Validation](#node-validation)
  - [UI Helper Functions](#ui-helper-functions)
  - [Node Access Functions](#node-access-functions)
  - [Connection Functions](#connection-functions)
  - [Import Resolution](#import-resolution)
- [commandM.sh — Command Manager](#commandmsh--command-manager)
  - [Project Commands](#project-commands)
  - [Node Commands](#node-commands)
  - [Connection Commands](#connection-commands)
  - [List Commands](#list-commands)
  - [Export](#export)
  - [Help & Clear](#help--clear)
- [flowM.sh — Flow Manager](#flowmsh--flow-manager)
  - [Root Detection](#root-detection)
  - [Execution Engine](#execution-engine)
  - [Background Runs](#background-runs)
  - [Sort](#sort)
  - [Tree View](#tree-view)
  - [REPL Reference](#repl-reference)
- [Quick-Start Walkthrough](#quick-start-walkthrough)

---

## Overview

FLOW-SN is a bash-based workflow engine. Workflows are directed graphs of **nodes** — each node holds a script, text block, decision condition, or variable — connected by directed edges. The engine traverses the graph from `start` to `end`, executing each node in order.

Three source files power it:

| File | Role |
|---|---|
| `UIM` | Shared UI primitives, storage helpers, node/connection I/O |
| `commandM.sh` | All CRUD commands (add, edit, connect, export, …) |
| `flowM.sh` | Execution engine, tree view, background runs, REPL |

**To start the REPL:**

```bash
bash flowM.sh
```

---

## Data Layout

```
~/.flowterm/
├── .projects                        # registry of all project names
├── project1/                        # default project
│   ├── nodes/
│   │   ├── start.node
│   │   ├── end.node
│   │   └── fetch_data.node
│   ├── connections                  # "from to [branch]" — one per line
│   ├── fetch_data_bg.log
│   ├── check_status_decision.log
│   └── runs/
│       └── project1_20260511_203000/
│           ├── meta
│           ├── run.log
│           ├── workflow.status      # RUNNING | COMPLETE | ERROR
│           ├── connections.snap
│           ├── snapshot_nodes/
│           ├── node_fetch_data.log
│           ├── node_fetch_data.status
│           └── ...
└── reporting/
    └── ...
```

---

## UIM — UI Manager

> **Do not execute directly.** Source it from other scripts:
>
> ```bash
> source ./UIM
> ```

---

### Color Variables

ANSI escape codes for terminal output. Use them inside `echo -e` or `printf` calls.

| Variable | Color | Purpose | Example usage |
|---|---|---|---|
| `OR` | Orange | Primary accent, node names | `echo -e "${OR}my_node${RS}"` |
| `OD` | Orange dim | Warnings | `echo -e "${OD}! low disk space${RS}"` |
| `GR` | Green | Success, true branch | `echo -e "${GR}✓ done${RS}"` |
| `RE` | Red | Errors, false branch | `echo -e "${RE}✗ failed${RS}"` |
| `BL` | Blue | Language tags | `echo -e "${BL}[bash]${RS}"` |
| `GL` | Grey light | Labels, info prefix | `echo -e "${GL}· nodes: 4${RS}"` |
| `GY` | Grey | Tree art, dividers | `echo -e "${GY}──────────${RS}"` |
| `WH` | White | Body text | `echo -e "${WH}Hello world${RS}"` |
| `WD` | White dim | Secondary text | `echo -e "${WD}(no body)${RS}"` |
| `CY` | Cyan | Decision nodes | `echo -e "${CY}[decision]${RS}"` |
| `MA` | Magenta | Variable nodes | `echo -e "${MA}[variable]${RS}"` |
| `BD` | Bold | Emphasis | `echo -e "${BD}Important${RS}"` |
| `DM` | Dim | De-emphasis | `echo -e "${DM}deprecated${RS}"` |
| `RS` | Reset | Always terminate a colored string | `echo -e "${GR}ok${RS}"` |

---

### Storage & Paths

| Variable | Default | Description |
|---|---|---|
| `DATA` | `$HOME/.flowterm` | Base directory for all projects |
| `PROJ` | `project1` | Currently active project name |
| `NODES` | `$DATA/$PROJ/nodes/` | Directory of `.node` files |
| `CONNS` | `$DATA/$PROJ/connections` | Flat connections file |

**`use_proj <name>`** — Switch to a project, creating its directories and files if they don't exist.

```bash
use_proj reporting
# Sets PROJ=reporting, NODES=~/.flowterm/reporting/nodes/, etc.
# Creates the directory tree if it doesn't exist.
```

---

### Node File Format

Each node is stored as `$NODES/<name>.node` — a plain text file with exactly this structure:

```
<type>       ← line 1: start | end | command
<subtype>    ← line 2: passthrough | text | script | decision | variable | sleep
<language>   ← line 3: bash | python3 | node | ruby | -
<body>       ← line 4+: the node's content (may be empty or multi-line)
```

**Example — a bash script node:**

```
command
script
bash
curl -s https://api.example.com/status | jq .status
```

**Example — a decision node:**

```
command
decision
python3
import requests
r = requests.get("https://api.example.com/health")
print("true" if r.status_code == 200 else "false")
```

**Example — a sleep node:**

```
command
sleep
-
5
```

---

### Node Validation

**`validate_node_name <name>`** — Returns non-zero and prints an error for any of:

| Rule | Bad example | Good example |
|---|---|---|
| Empty string | `""` | `"fetch_data"` |
| Characters outside `[a-zA-Z0-9_-]` | `"my node"`, `"get@data"` | `"my_node"`, `"get-data"` |
| Starts with a hyphen | `"-start"` | `"start2"` |
| Exactly `.` or `..` | `"."` | `"root"` |

```bash
validate_node_name "fetch-data"   # → 0 (valid)
validate_node_name "my node"      # → 1, prints error: invalid characters
validate_node_name "-bad"         # → 1, prints error: starts with hyphen
```

---

### Legacy Migration

**`migrate_legacy`** — Runs automatically on first launch. If `~/.flowterm/nodes/` or `~/.flowterm/connections` exist at the top level (pre-v1.2 layout), they are moved into `~/.flowterm/project1/` without data loss. No action is taken if the new layout already exists.

---

### UI Helper Functions

| Function | Output | Example |
|---|---|---|
| `ok "msg"` | `✓ msg` in green | `ok "node saved"` → `✓ node saved` |
| `err "msg"` | `✗ msg` in red | `err "node not found"` → `✗ node not found` |
| `info "msg"` | `· msg` in grey | `info "3 nodes loaded"` → `· 3 nodes loaded` |
| `warn "msg"` | `! msg` in orange dim | `warn "no connections"` → `! no connections` |
| `hdr "title"` | Section header with orange title + grey rule | `hdr "Execution"` |
| `div` | Grey divider line | `div` |
| `banner` | Full ASCII art banner (v1.2.4) | `banner` |
| `prompt_line` | Input prompt with project status indicator | Used internally by REPL |

```bash
hdr "Node Details"
info "name:    fetch_data"
info "subtype: script"
ok "body loaded (4 lines)"
div
```

Output:

```
── Node Details ─────────────────────
· name:    fetch_data
· subtype: script
✓ body loaded (4 lines)
─────────────────────────────────────
```

---

### Node Access Functions

| Function | Description |
|---|---|
| `node_file <name>` | Returns full path to `<name>.node` |
| `node_exists <name>` | Returns 0 if file exists, 1 otherwise |
| `node_type <name>` | Reads line 1 (`start`, `end`, `command`) |
| `node_subtype <name>` | Reads line 2 |
| `node_lang <name>` | Reads line 3 |
| `node_body <name>` | Reads lines 4+ |
| `node_save <name> <type> <sub> <lang> <body>` | Writes (or overwrites) a node file |
| `node_list` | Lists all node names in the current project |
| `node_delete <name>` | Removes the node file and all its connections |

**Examples:**

```bash
# Check if a node exists before operating on it
if node_exists "fetch_data"; then
  echo "subtype: $(node_subtype fetch_data)"
  echo "lang:    $(node_lang fetch_data)"
fi

# Get the body of a node
body=$(node_body fetch_data)
echo "$body"

# Save a new node programmatically
node_save "greet" "command" "text" "-" "Hello from FLOW-SN!"

# List all nodes
node_list
# → start
# → fetch_data
# → check_status
# → notify
# → end

# Delete a node (also removes its connections)
node_delete "old_node"
```

---

### Connection Functions

| Function | Description |
|---|---|
| `conn_add <from> <to> [branch]` | Adds a connection; ignores exact duplicates |
| `conn_remove <from> <to>` | Removes all connections between two nodes |
| `conn_out <node> [branch]` | Lists children; pass `"true"` or `"false"` to filter by branch |
| `conn_in <node>` | Lists all parent nodes |
| `conn_branch <from> <to>` | Returns the branch tag (`true`, `false`, or empty) |

**Examples:**

```bash
# Basic connection
conn_add "fetch_data" "check_status"

# Decision branch connections
conn_add "check_status" "notify_success" "true"
conn_add "check_status" "notify_failure" "false"

# List all children of a node
conn_out "check_status"
# → notify_success
# → notify_failure

# Filter by branch
conn_out "check_status" "true"
# → notify_success

# List parents
conn_in "notify_success"
# → check_status

# Get the branch label on an edge
conn_branch "check_status" "notify_success"
# → true

# Remove a connection
conn_remove "fetch_data" "check_status"
```

---

### Import Resolution

**`resolve_imports <lang> <body>`** — Scans a script body for `import <name>` directives and injects the referenced node's body inline, wrapped appropriately for the target language. Import lines are stripped from the final output.

**Node types and how they're injected:**

| Referenced node subtype | Injection style |
|---|---|
| `variable` | Body injected raw (language must match) |
| `decision` | Body wrapped in a callable function; returns a boolean |
| Not found / language mismatch | Comment annotation injected; no crash |

**Language wrapper styles:**

| Language | Function wrapper | Call style |
|---|---|---|
| `python3` | `def <name>():` — captures stdout via `io.StringIO` | `if <name>():` |
| `bash` / `sh` | `<name>() { _out=$( … ); [[ $_out == "true" ]] … }` | `if <name>; then` |
| `node` / `js` | `function <name>() {` — captures `process.stdout.write` | `if (<name>())` |
| `ruby` | `def <name>` — captures `$stdout` via `StringIO` | `if <name>` |

**Example:**

You have a decision node named `is_healthy` (python3):

```python
import requests
r = requests.get("https://api.example.com/health")
print("true" if r.status_code == 200 else "false")
```

And a script node that imports it:

```python
import is_healthy

if is_healthy():
    print("Proceeding with pipeline...")
```

After `resolve_imports`, the executed body becomes:

```python
import io, sys

def is_healthy():
    _buf = io.StringIO()
    _old = sys.stdout
    sys.stdout = _buf
    import requests
    r = requests.get("https://api.example.com/health")
    print("true" if r.status_code == 200 else "false")
    sys.stdout = _old
    return _buf.getvalue().strip() == "true"

if is_healthy():
    print("Proceeding with pipeline...")
```

---

## commandM.sh — Command Manager

Sources `UIM`. Provides all CRUD operations for nodes, projects, and export.

---

### Project Commands

#### `cmd_init [name]`

Creates a new project with default `start` and `end` nodes. Registers it in `.projects`.

```
flow> init my_pipeline
✓ project 'my_pipeline' created
· added: start, end
```

```
flow> init
✓ project 'project1' created   ← defaults to 'project1'
```

---

#### `cmd_switch <name>`

Switches the active project to an existing one.

```
flow> switch reporting
✓ switched to project 'reporting'
```

---

#### `cmd_projects`

Lists all projects with their node counts.

```
flow> projects
  project1      (6 nodes)
  reporting     (3 nodes)
* my_pipeline   (2 nodes)   ← * marks the active project
```

---

#### `cmd_rmproj <name>`

Deletes a project directory and removes it from the registry. Asks for confirmation.

```
flow> rmproj old_project
! This will permanently delete 'old_project' and all its nodes. Continue? [y/N] y
✓ project 'old_project' deleted
```

---

#### `cmd_reset`

Wipes all nodes and connections in the current project, then recreates `start` and `end`. Asks for confirmation.

```
flow> reset
! This will delete all nodes and connections in 'my_pipeline'. Continue? [y/N] y
✓ project reset — start and end nodes restored
```

---

### Node Commands

#### `cmd_add <name> [subtype] [lang]`

Adds a new node. Subtypes: `passthrough`, `text`, `script`, `decision`, `variable`, `sleep`.

```
flow> add fetch_data script bash
✓ node 'fetch_data' added  [command / script / bash]

flow> add status_check decision python3
✓ node 'status_check' added  [command / decision / python3]

flow> add separator passthrough
✓ node 'separator' added  [command / passthrough / -]

flow> add pause sleep
✓ node 'pause' added  [command / sleep / -]
```

---

#### `cmd_setbody <name> <content>`

Sets a node's body inline (single line). For multi-line content, use `cmd_edit`.

```
flow> setbody pause 10
✓ body updated for 'pause'

flow> setbody greet "echo Hello, world!"
✓ body updated for 'greet'
```

---

#### `cmd_edit <name>`

Interactive editor — walks through subtype, language, and body. Type `KEEP` at the body prompt to preserve the existing body.

```
flow> edit fetch_data
current subtype: script
new subtype (or ENTER to keep): 
current lang: bash
new lang (or ENTER to keep): 
current body:
  curl -s https://api.example.com/status
new body (KEEP to preserve, or paste new):
  curl -s https://api.example.com/v2/status | jq .
✓ node 'fetch_data' updated
```

---

#### `cmd_show <name>`

Full node inspection — type, subtype, language, body, detected imports, and all connections.

```
flow> show fetch_data
── fetch_data ───────────────────────
  type:     command
  subtype:  script
  lang:     bash
  imports:  (none)
  body:
    curl -s https://api.example.com/v2/status | jq .
  connections:
    → check_status
─────────────────────────────────────
```

---

#### `cmd_delete <name>`

Removes a node and all its connections. Asks for confirmation. `start` and `end` cannot be deleted.

```
flow> delete old_node
! Delete 'old_node' and all its connections? [y/N] y
✓ node 'old_node' deleted
```

---

### Connection Commands

#### `cmd_connect <from> <to> [true|false]`

Links two nodes. Decision nodes require a branch tag (`true` or `false`).

```
flow> connect start fetch_data
✓ connected: start → fetch_data

flow> connect fetch_data check_status
✓ connected: fetch_data → check_status

flow> connect check_status notify_success true
✓ connected: check_status → notify_success  [true]

flow> connect check_status notify_failure false
✓ connected: check_status → notify_failure  [false]
```

---

#### `cmd_disconnect <from> <to>`

Removes a link between two nodes.

```
flow> disconnect old_step new_step
✓ disconnected: old_step → new_step
```

---

### List Commands

#### `cmd_list`

Lists all nodes and connections in the current project.

```
flow> list
── my_pipeline ──────────────────────
nodes:
  start         [start / - / -]
  fetch_data    [command / script / bash]
  check_status  [command / decision / python3]
  notify        [command / text / -]
  end           [end / - / -]

connections:
  start → fetch_data
  fetch_data → check_status
  check_status → notify  [true]
  notify → end
─────────────────────────────────────
```

---

#### `cmd_list --all`

Lists all projects and their nodes.

```
flow> list --all
── project1 ──────────────────────
  start, greet, end
── my_pipeline ───────────────────
  start, fetch_data, check_status, notify, end
```

---

### Export

#### `cmd_export [file]`

Exports the full workflow as a standalone bash script, starting from `start`. All imports are resolved so the output is self-contained. Defaults to `workflow_export.sh`.

```
flow> export
✓ exported to workflow_export.sh

flow> export /tmp/my_pipeline_v2.sh
✓ exported to /tmp/my_pipeline_v2.sh
```

The exported script can be run directly:

```bash
bash workflow_export.sh
```

---

### Help & Clear

#### `cmd_help`

Prints all available commands with descriptions and a quick-start example.

```
flow> help
```

#### `cmd_clear`

Clears the terminal and re-displays the banner with current project info.

```
flow> clear
```

---

## flowM.sh — Flow Manager

Sources `UIM` and `commandM.sh`. Provides the execution engine, tree view, background runs, and the REPL.

---

### Root Detection

**`_check_root`** — Runs automatically at startup. Sets `_IS_ROOT=1` if EUID is 0 or if passwordless `sudo` is available. The REPL displays a root indicator on the status line when active.

```
[root] my_pipeline> run
```

---

### Execution Engine

#### `run_node <id> <prefix> <branch> <is_last>`

Recursive graph traversal. Called internally by `cmd_run`. For each node:

1. **Cycle guard** — already-visited nodes are skipped to prevent infinite loops.
2. **Type dispatch:** `start` prints a counter and passes through; `end` terminates traversal; `command` dispatches to a subtype handler.
3. **Subtype dispatch:**
   - `passthrough` — prints status line, no execution
   - `script` — runs via `_exec_node`
   - `text` — prints body via `_exec_node`
   - `sleep` — pauses for the duration in the node body
   - `decision` — evaluates condition, follows `true` or `false` branch
   - `variable` — skipped (not directly executable; used via imports)
4. Recurses into children in connection order.

---

#### `_exec_node <id> <sub> <lang> <body> <prefix>`

Executes a node and prints formatted output.

- **Script nodes** — resolves imports, detects loops (via keyword scan), runs in a background subshell.
  - Scripts containing loops get a **5-line peek** then detach with a PID display.
  - Short scripts wait for exit and show full output.
- **Text nodes** — prints body lines with formatting.
- **Sleep nodes** — prints a "sleeping N seconds…" line, sleeps, then prints "resumed."

**Loop-detection keyword scan** checks the body for: `while`, `for`, `until`, `loop`, `repeat`.

---

#### Decision Node Execution

1. Evaluates the condition script in the node's language.
2. Captures stdout and trims whitespace.
3. If output is exactly `"true"` → follows the `true` branch; anything else → `false` branch.
4. Prints the taken branch label and recurses into that branch's children.
5. Missing branches (e.g. a decision node with only a `true` edge) are silently skipped.

**Example decision node (bash):**

```bash
# node: check_disk
# subtype: decision, lang: bash
used=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
[ "$used" -lt 90 ] && echo "true" || echo "false"
```

When evaluated:
```
  ◆ check_disk [decision]
    → took branch: true
```

---

### Foreground Run

#### `cmd_run`

Resets the visited-node list (pre-seeding `end` as visited to avoid re-entry), then starts traversal from `start`. Prints a connections summary on completion.

```
flow> run
  ● start
  ○ fetch_data [script/bash]
    curl -s https://api.example.com/v2/status | jq .
    {"status": "ok", "uptime": 99.98}
  ◆ check_status [decision/python3]
    → took branch: true
  ○ notify [text]
    Pipeline completed successfully.
  ■ end

── connections summary ──────────────
connected:    start fetch_data check_status notify end
disconnected: (none)
─────────────────────────────────────
```

---

### Background Runs

#### `cmd_runbg`

Launches the workflow fully detached with snapshot isolation. The current node files and connections are copied at launch time — edits made after `runbg` don't affect the running session.

```
flow> runbg
✓ run started  [my_pipeline_20260511_203045]
  PID: 48291
  logs: ~/.flowterm/runs/my_pipeline_20260511_203045/
```

**Session directory layout:**

```
~/.flowterm/runs/my_pipeline_20260511_203045/
├── meta                      # project, run_id, start time, PID
├── run.log                   # combined execution log
├── workflow.status           # RUNNING | COMPLETE | ERROR
├── connections.snap
├── snapshot_nodes/           # isolated copies of all .node files
├── node_fetch_data.log
├── node_fetch_data.status    # PENDING | RUNNING | DONE | ERROR
├── node_check_status.log
└── ...
```

**Session registry:** each run is appended to `~/.flowterm/runs/.registry` for lookup.

---

### Sort

#### `cmd_sort <node>`

Interactive reordering of a node's outgoing connections. Useful for controlling execution order when a node has multiple children.

```
flow> sort check_status
current order:
  1. notify_failure  [false]
  2. notify_success  [true]

new order (space-separated numbers): 2 1
✓ reordered:
  1. notify_success  [true]
  2. notify_failure  [false]
```

Validation enforced: correct count, no duplicates, all numbers in range.

---

### Connections Summary

#### `_print_connections_summary`

Called automatically after `cmd_run`. Prints two sections:

- **Connected nodes** — appear in the connections file
- **Disconnected nodes** — exist in the node list but aren't referenced by any connection

```
── connections summary ──────────────
connected:
  start → fetch_data → check_status → notify → end

disconnected:
  draft_node
  archived_step
─────────────────────────────────────
```

---

### Tree View

#### `cmd_tree`

ASCII tree visualization of the entire workflow. Starts from `start`, then appends any unreachable nodes at the bottom.

Each node shows:
- Node name (colored by subtype)
- Subtype badge
- Language tag
- First line of body preview
- Import count (if any)
- Outgoing arrows with branch labels

```
flow> tree

  ● start
  │
  └─○ fetch_data  [script/bash]  "curl -s https://api.example.com…"
    │
    └─◆ check_status  [decision/python3]  "r = requests.get(…"
      │
      ├─[true]──○ notify_success  [text]  "Pipeline OK."
      │         └─■ end
      │
      └─[false]─○ notify_failure  [text]  "Pipeline failed."
                └─■ end

── unreachable ──────────────────────
  ○ draft_node  [script/bash]  "(empty)"
─────────────────────────────────────
```

---

### REPL Reference

Launch with `bash flowM.sh`. The prompt shows the current project and root status:

```
my_pipeline> _
[root] my_pipeline> _
```

Full command reference:

| Command | Description |
|---|---|
| `init [name]` | Create a new project |
| `switch <name>` | Switch to an existing project |
| `projects` | List all projects |
| `rmproj <name>` | Delete a project |
| `reset` | Wipe current project's nodes and connections |
| `add <name> [sub] [lang]` | Add a node |
| `setbody <name> <content>` | Set node body inline |
| `edit <name>` | Interactive node editor |
| `show <name>` | Inspect a node fully |
| `delete <name>` | Remove a node and its connections |
| `connect <from> <to> [branch]` | Link two nodes |
| `disconnect <from> <to>` | Unlink two nodes |
| `list [--all]` | List nodes/connections (or all projects) |
| `sort <node>` | Reorder a node's children |
| `tree` | ASCII tree of the workflow |
| `run` | Execute the workflow (foreground) |
| `runbg` | Execute the workflow (detached background) |
| `export [file]` | Export to a standalone bash script |
| `clear` | Clear terminal, redisplay banner |
| `help` / `h` / `?` | Show all commands |
| `exit` / `quit` / `q` | Exit the REPL |

---

## Quick-Start Walkthrough

A minimal pipeline that fetches an API, checks its status, and prints a result.

```
flow> init health_check
✓ project 'health_check' created

flow> add fetch script bash
✓ node 'fetch' added

flow> setbody fetch "curl -s https://api.example.com/health -o /tmp/health.json"
✓ body updated for 'fetch'

flow> add is_up decision bash
✓ node 'is_up' added

flow> setbody is_up "grep -q '\"status\":\"ok\"' /tmp/health.json && echo true || echo false"
✓ body updated for 'is_up'

flow> add all_good text -
✓ node 'all_good' added

flow> setbody all_good "Service is healthy. ✓"
✓ body updated for 'all_good'

flow> add degraded text -
✓ node 'degraded' added

flow> setbody degraded "WARNING: Service is down or degraded."
✓ body updated for 'degraded'

flow> connect start fetch
flow> connect fetch is_up
flow> connect is_up all_good true
flow> connect is_up degraded false
flow> connect all_good end
flow> connect degraded end

flow> tree
  ● start
  └─○ fetch [script/bash]  "curl -s https://…"
    └─◆ is_up [decision/bash]  "grep -q …"
      ├─[true]──○ all_good [text]  "Service is healthy. ✓"
      │         └─■ end
      └─[false]─○ degraded [text]  "WARNING: Service is down…"
                └─■ end

flow> run
  ● start
  ○ fetch
  ◆ is_up → took branch: true
  ○ all_good
    Service is healthy. ✓
  ■ end

flow> export health_check.sh
✓ exported to health_check.sh
```

---

*FLOW-SN v1.2.4 — Created by Azaraeth (Solora Network)*
