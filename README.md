# ⬡ FLOW-SN

> A terminal-based workflow runner for Termux on Android and Linux. Build pipelines, connect nodes, execute everything — fully offline, no cloud, no dependencies beyond bash.

**v1.2.3** · Created by [Azaraeth](https://github.com/azaraeth)

---

## What is Flow-SN?

Flow-SN is an open source workflow environment that lets you build, visualize, and execute script pipelines from the terminal. You connect **nodes** to form a graph — Flow-SN walks that graph and runs everything in sequence, printing a live tree as it goes.

Loops and long-running processes (like `ollama serve`) run in the background automatically. Flow-SN never blocks on them — it peeks at the first few lines of output, shows you the PID and log path, then moves on. Short scripts run inline and show their full output.

No internet. No cloud. Just your scripts, running the way you designed them.

---

## Features

- **Fully offline** — no network calls, no external services
- **Multi-language nodes** — bash, python3, node, and ruby out of the box
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
| `add <name> [sub] [lang]` | Add a node — sub: `passthrough`, `text`, `script`, `decision` |
| `setbody <name> <content>` | Set a node's body inline |
| `edit <name>` | Interactively edit a node's subtype, lang, and body |
| `show <name>` | Inspect a node's full details |
| `delete <name>` | Remove a node |

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
