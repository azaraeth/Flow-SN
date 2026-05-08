# ⬡ sn-flow v1.2.3

> Open source workflow environment for offline usage with multiple script compatibilities and background stable running content for better multi-tasking workflows.

Built for **Termux** on Android and **Linux**. No internet required. No cloud. Just your scripts, running the way you designed them.

---

## What is sn-flow?

flow is a terminal-based workflow runner that lets you build, visualize, and execute pipelines made of connected nodes. Each node can run a script, output text, pass through silently, or branch conditionally. Nodes connect to form a graph — flow walks that graph and executes everything in order, printing a live tree as it goes.

Loops and long-running processes (like `ollama serve`) run in the background automatically — flow never blocks waiting for them. It peeks at their first few lines of output, shows you the PID and log path, then moves on.

---

## Features

- **Fully offline** — no network calls, no dependencies beyond bash and your chosen runtimes
- **Multi-language scripts** — bash, python3, node, ruby supported out of the box
- **Decision nodes** — branch your workflow with true/false conditions written in any supported language
- **Fire-and-forget execution** — scripts launch in background, flow continues immediately
- **Loop detection** — looping scripts get a live peek (up to 5 lines) then run detached
- **Persistent background processes** — daemons like `ollama serve` are detected and handled gracefully
- **Live tree output** — colored, numbered, branch-art run view as workflow executes
- **Multiple projects** — switch between isolated workflow projects at any time
- **Interactive node editor** — edit node body, subtype, and language inline in the REPL
- **Sort children** — reorder the execution order of a node's children interactively
- **Export** — export any workflow to a standalone runnable bash script
- **Cycle guard** — infinite loops in the graph are automatically prevented

---

## Files

| File | Role |
|---|---|
| `flow` | Entry point — backwards-compatible wrapper, calls `flowM.sh` |
| `flowM.sh` | Execution engine, tree view, sort, REPL loop |
| `commandM.sh` | All CRUD commands — add, edit, connect, export, help |
| `UIM` | UI layer — colors, storage helpers, node read/write functions |

Data is stored at `~/.flowterm/<project>/` with one `.node` file per node and a `connections` file per project.

---

## Installation

**Termux (Android)**
```bash
git clone <repo>
cd flow
chmod +x flow flowM.sh
./flow
```

**Linux**
```bash
git clone <repo>
cd flow
chmod +x flow flowM.sh
./flow
```

No package installs required. For script nodes you need the relevant runtime (`python3`, `node`, `ruby`) already available in your environment.

---

## Quick Start

```
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

Output:
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
| `list` | List current project nodes and connections |
| `list --all` | List all projects and their nodes |
| `tree` | Show workflow as a tree (no execution) |
| `run` | Execute the workflow |
| `export [file.sh]` | Export workflow to a standalone bash script |
| `reset` | Wipe all nodes and connections in current project |

---

## Node Types

### `passthrough`
Does nothing, just connects flow from one point to another. Useful as a junction or placeholder.

```
add gate passthrough
```

### `text`
Prints a static string when executed.

```
add welcome text
setbody welcome Hello from flow!
```

### `script`
Runs code in the specified language. Supports `bash`, `sh`, `python`, `python3`, `node`, `nodejs`, `ruby`.

```
add fetch script bash
setbody fetch curl -s https://example.com
```

Scripts are detected as long-running if they contain a loop (`while`, `for`, `until`) or are short commands (≤ 3 words). Long-running scripts show a live peek and run detached. Quick scripts wait for exit and show full output.

### `decision`
Evaluates a condition written in any supported language and routes execution to a **true** or **false** branch based on the output. If the script prints exactly `true` to stdout, the true branch runs. Anything else (or no output) takes the false branch.

```
add check decision python3
```

Set the condition body — write natural code, no exit codes needed:

```
setbody check
a = 3
b = 0
if a == b:
    print("true")
END
```

Connect the branches:

```
connect check yes_node true
connect check no_node false
```

A missing branch is silently skipped — no crash, flow continues. Each branch runs as its own independent chain from that point forward.

Output during `run`:

```
1. check [executing...]  [decision:python3]
│  if
│  a = 3
│  b = 0
│  if a == b:
│      print("true")
└─ [true]  skip
   └─ [yes_node] skipped
└─ [false]  ◀ taken
   └─ 2. no_node [executing...] ✓ text
      ├ output [no_node]
      │ condition was false!
```

**Supported languages:** `bash`, `sh`, `python`, `python3`, `node`, `nodejs`, `js`, `ruby`

**Rule:** stdout must be exactly `true` (case-sensitive) to take the true branch. Anything else routes to false.

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

Every script node writes its output to:

```
~/.flowterm/<node-id>_bg.log
```

Decision nodes write their condition evaluation output to:

```
~/.flowterm/<node-id>_decision.log
```

You can tail any running script live:

```bash
tail -f ~/.flowterm/fetch_bg.log
```

---

## Color Palette

Defined in `UIM`:

| Variable | Code | Color |
|---|---|---|
| `OR` | `\033[38;5;208m` | Orange — node names, prompt |
| `OD` | `\033[38;5;166m` | Orange dim — arrows, warnings |
| `GR` | `\033[38;5;114m` | Green — success, end node, numbers |
| `RE` | `\033[38;5;203m` | Red — errors, false branch |
| `BL` | `\033[38;5;111m` | Blue — executing tag, lang |
| `GL` | `\033[38;5;245m` | Grey light — labels, info |
| `GY` | `\033[38;5;240m` | Grey — tree lines, pipes |
| `WH` | `\033[38;5;255m` | White — command node names |
| `WD` | `\033[38;5;250m` | White dim — body text, output |
| `CY` | `\033[38;5;87m`  | Cyan — decision nodes |

---

## Changelog

### v1.2.3
- Root detection on startup — shows `⚡ root access detected` if running as root or with passwordless sudo
- Non-root devices show a friendly notice: `Non rooted device is also compatible for workflow environment`
- Script nodes can use `sudo` commands naturally when root is available

### v1.2.2
- Linux compatibility — replaced hardcoded Termux shebangs with `#!/usr/bin/env bash`
- Now runs on any system with bash installed

### v1.2.1
- Added `decision` node type — conditional branching with true/false paths
- `connect` now accepts an optional `true`/`false` branch argument for decision nodes
- Connections file supports optional 3rd column for branch tags
- `list` and `show` display branch labels on decision connections
- Added `CY` (cyan) color for decision node highlighting in tree and run view
- Decision condition evaluation logs written to `~/.flowterm/<node-id>_decision.log`

### v1.2.0
- Initial open source release

---

## Created by Azaraeth
