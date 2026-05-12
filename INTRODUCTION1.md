# Introduction to SN-Flow

```
     ███████╗███╗   ██╗      ███████╗██╗      ██████╗ ██╗    ██╗
     ██╔════╝████╗  ██║      ██╔════╝██║     ██╔═══██╗██║    ██║
     ███████╗██╔██╗ ██║█████╗█████╗  ██║     ██║   ██║██║ █╗ ██║
     ╚════██║██║╚██╗██║╚════╝██╔══╝  ██║     ██║   ██║██║███╗██║
     ███████║██║ ╚████║      ██║     ███████╗╚██████╔╝╚███╔███╔╝
     ╚══════╝╚═╝  ╚═══╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝
     V1.2.4 OPENSOURCE
```

> ⬡ **sn-flow** · workflow runner — Created by **Azaraeth**

---

## What is SN-Flow?

SN-Flow is a **terminal-native workflow automation tool** built entirely in Bash. It lets you design, manage, and execute multi-step automated workflows directly from your shell — no GUI, no cloud dependency, no external orchestration service required.

Think of it as a lightweight, programmable pipeline builder that lives in your terminal. You define individual units of work called **nodes**, wire them together into a directed graph, and then execute the entire workflow with a single command. Each node can run a shell script, evaluate a condition, output text, pause for a set duration, or simply pass execution along to the next step.

SN-Flow is designed to be simple enough to use on a bare Linux or Android (Termux) environment, yet flexible enough to handle branching logic, multi-language scripting, background execution, and reusable code modules — all from an interactive REPL that fits in a single terminal window.

---

## Why SN-Flow?

Most automation tools — Airflow, GitHub Actions, Make, Ansible — are either too heavy, too cloud-dependent, or require complex configuration files. SN-Flow takes a different approach:

- **No YAML. No XML. No DSL.** Workflows are built interactively through a conversational command prompt.
- **No daemon. No server.** It runs directly as a Bash process. If your terminal works, SN-Flow works.
- **No dependencies beyond Bash.** Optional language runtimes (Python, Node.js, Ruby) are only needed if you actually use those languages in your nodes.
- **Runs anywhere Bash runs.** Linux, macOS, WSL, Termux (Android) — rooted or non-rooted.

It is purpose-built for developers, system administrators, and power users who want to automate sequences of tasks without leaving the terminal.

---

## Core Concepts

SN-Flow models automation as a **directed graph** — a flowchart made of nodes and connections.

### Nodes

A **node** is a single unit of work. It has a name, a type, and a body (the content it executes or displays). Every workflow starts at a `start` node and ends at an `end` node. Everything in between is up to you.

### Connections

Nodes are linked by **connections** — directed edges that tell SN-Flow which node to execute next. A node can have multiple outgoing connections (fan-out) and multiple incoming connections (fan-in).

### Projects

A **project** is a named collection of nodes and connections. You can have multiple projects and switch between them freely. Each project is fully isolated.

### The REPL

SN-Flow is operated through an interactive **Read-Eval-Print Loop** (REPL) — a persistent command prompt where you type commands to build and run your workflows. You don't write config files; you build your workflow live, inspect it, modify it, and run it — all in the same session.

---

## Capabilities

### Multi-Language Script Execution

Script nodes can execute code in any of the four supported runtimes:

- **Bash / Shell** — for system commands, file operations, and shell scripting
- **Python 3** — for data processing, API calls, JSON handling, and general scripting
- **Node.js** — for JavaScript logic, npm-available utilities, and async-friendly tasks
- **Ruby** — for Ruby-based automation and scripting tasks

Each script node specifies its language at creation time. The runner invokes the appropriate interpreter automatically.

```bash
add backup script bash
setbody backup tar -czf /tmp/backup.tar.gz ~/Documents

add parse script python3
setbody parse import json; data=open("out.json").read(); print(json.loads(data)["status"])
```

### Conditional Branching with Decision Nodes

Decision nodes evaluate a condition and route execution down one of two paths — `true` or `false`. The condition is a script that must print exactly `true` or `false` to stdout. This enables real if/else logic inside your workflow.

```bash
add check_disk decision bash
setbody check_disk [ $(df / | awk 'NR==2{print $5}' | tr -d '%') -lt 90 ] && echo true || echo false

connect check_disk deploy true
connect check_disk alert  false
```

Only the taken branch is executed and displayed — the other path is skipped entirely.

### Reusable Code with Variable Nodes

Variable nodes store shared code — constants, environment variables, helper functions — that can be injected into any compatible script or decision node using the `import` directive. This avoids copy-pasting the same setup code across multiple nodes.

```bash
add config variable bash
setbody config BASE_URL=https://api.example.com; RETRY=3

add fetch script bash
setbody fetch import config
# At runtime: BASE_URL and RETRY are available as shell variables
curl -s --retry $RETRY $BASE_URL/status
```

Variable nodes are never executed on their own — they only exist to be imported.

### Foreground and Background Execution

Workflows can be run in two modes:

**Foreground (`run`)** — executes the workflow in the current terminal session with a live, tree-style output showing each node as it runs, its output, and elapsed time. Ideal for monitoring and debugging.

**Background (`runbg`)** — launches the workflow as a fully detached subprocess. The session is isolated in its own directory with per-node log files and status files. You can start a background run, close the prompt, and check the logs later. Useful for long-running pipelines.

### Workflow Visualization with Tree View

The `tree` command renders your entire workflow as an ASCII tree — showing node types, subtypes, language badges, connection arrows, import counts, and a body preview for each node. This gives you a bird's-eye view of your pipeline without running it.

```
   [start] →fetch
   └─ [fetch] [bash] →check_env
      │  import config
      └─ [check_env] [decision:bash] →deploy →abort
         └─ [deploy] [bash]
         └─ [abort] [text]
```

### Export to Standalone Script

The `export` command compiles your entire workflow — including all import resolutions — into a single, self-contained bash script. The exported file has no dependency on SN-Flow and can be run on any machine with Bash. It's a clean way to share or deploy a workflow without requiring the recipient to install anything.

```bash
export deploy_pipeline.sh
bash deploy_pipeline.sh
```

### Multi-Project Support

SN-Flow supports any number of named projects stored under `~/.flowterm/`. You can switch between projects instantly, list all projects with node counts, and delete projects you no longer need. Each project has its own isolated set of nodes, connections, and background run history.

### Node Ordering Control

When a node has multiple outgoing connections, the order in which children are executed matters. The `sort` command lets you interactively reorder a node's children without disconnecting and reconnecting them — just enter the new order as numbers.

### Sleep / Delay Nodes

Sleep nodes pause the workflow for a specified number of seconds (including fractional values like `0.5`). They are useful for rate limiting, waiting for an external service to become ready, or introducing deliberate delays between steps.

```bash
add cooldown sleep
setbody cooldown 1.5
```

### Data Persistence

All workflow data is stored as plain text files under `~/.flowterm/`. There is no database, no binary format, and no locked file. Node files use a simple 3-line header (type, subtype, language) followed by the body. Connection data is a plain space-separated text file. This means your workflows are fully portable, human-readable, and easy to back up or version-control.

---

## Who Is It For?

SN-Flow is a good fit if you:

- Want to automate multi-step tasks (deployments, backups, data pipelines, health checks) without writing a full-blown script from scratch every time
- Work primarily in the terminal and prefer staying there
- Need lightweight automation on a resource-constrained device (VPS, Raspberry Pi, Android via Termux)
- Want to prototype a workflow interactively before committing it to a script
- Need branching logic in your automation without reaching for a heavyweight tool
- Want to share a workflow as a single self-contained script via `export`

---

## What SN-Flow Is Not

SN-Flow is a **single-user, single-machine** tool. It is not designed for:

- **Distributed execution** — nodes run on the machine where SN-Flow is installed, not across a cluster
- **Parallel execution** — the default runner is sequential; `runbg` detaches the whole workflow but does not parallelize individual nodes
- **Scheduling** — there is no built-in cron-like scheduler; use your system's cron or systemd timer to trigger `run`
- **Secret management** — credentials written into node bodies are stored as plain text; use environment variables or external secret managers for sensitive data
- **Production orchestration at scale** — for enterprise-scale pipelines, consider dedicated tools like Airflow, Prefect, or Temporal

---

## Design Philosophy

SN-Flow is built on a few deliberate choices:

**Everything in the terminal.** The REPL, the output, the logs — nothing requires a browser or a separate dashboard. Your workflow lives where your work lives.

**Plain text is the truth.** Nodes and connections are stored as human-readable files. You can inspect, edit, or version-control them with any standard tool.

**Build incrementally.** You don't have to design the whole workflow upfront. Add a node, connect it, run it, adjust. The REPL makes iteration fast and low-friction.

**Self-contained by default.** The `export` command means your workflow is never locked in to SN-Flow. At any point you can produce a standalone script and walk away.

**Minimal footprint.** No runtime to install, no background service to manage, no configuration file to maintain. Clone the repo, run `./flow`, and you're building.

---

```bash
# Launch SN-Flow
./flow

# Build your first workflow
init hello
add greet text
setbody greet Hello from SN-Flow!
connect start greet
connect greet end
run
```

That's all it takes to run your first workflow.
