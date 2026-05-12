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

## Comparison to Other Workflow Tools

SN-Flow occupies a very specific niche. The table below gives a quick orientation, followed by detailed breakdowns of each tool.

### At a Glance

| Feature | SN-Flow | n8n | Apache Airflow | GitHub Actions | Make (Integromat) | Prefect | Zapier |
|---|---|---|---|---|---|---|---|
| Interface | Terminal REPL | Web GUI | Web GUI | YAML / Web | Web GUI | Python SDK + UI | Web GUI |
| Self-hosted | ✅ | ✅ / ☁️ | ✅ | ☁️ (runners) | ☁️ | ✅ / ☁️ | ☁️ only |
| No-install run | ✅ (just Bash) | ❌ (Node + DB) | ❌ (Python + DB) | ❌ | ❌ | ❌ | ❌ |
| Offline capable | ✅ | ✅ (self-hosted) | ✅ (self-hosted) | ❌ | ❌ | ✅ (self-hosted) | ❌ |
| Branching logic | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Limited |
| Multi-language scripts | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Built-in integrations | ❌ | ✅ (400+) | ✅ (providers) | ✅ (marketplace) | ✅ (1000+) | ✅ | ✅ (6000+) |
| Scheduling | ❌ (use cron) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Parallel execution | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Resource footprint | Minimal (Bash) | Medium (Node+DB) | Heavy (Python+DB) | Cloud | Cloud | Medium | Cloud |
| Runs on Termux/Android | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Export to standalone script | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Vendor lock-in | None | Low | Low | Medium | High | Low | Very High |
| Free to use | ✅ (fully open) | ✅ (community) | ✅ (Apache) | Limited free tier | Limited free tier | Limited free tier | Limited free tier |

---

### SN-Flow vs n8n

**n8n** is a popular open-source workflow automation platform with a drag-and-drop visual editor, 400+ built-in integrations (Slack, Notion, Google Sheets, webhooks, databases, etc.), and a self-hostable Node.js server.

#### Where n8n wins
- Visual, drag-and-drop canvas — no terminal knowledge required
- Massive library of pre-built integration nodes for third-party services
- Built-in scheduling, webhook triggers, and event-driven workflows
- Parallel branch execution
- Active community and plugin ecosystem
- Credential management with encryption

#### Where SN-Flow wins
- **Zero setup.** n8n requires Node.js, npm, and a running database (SQLite or PostgreSQL). SN-Flow requires Bash — which is already installed on every Unix system.
- **Runs anywhere.** n8n cannot run on Termux or other minimal environments. SN-Flow can.
- **No browser needed.** n8n's entire UX is a web app. SN-Flow works over SSH, in headless servers, and in environments with no graphical interface at all.
- **Export to plain script.** n8n workflows are locked in its internal JSON format. SN-Flow workflows can be exported to a standalone bash script with a single command.
- **No vendor account.** n8n cloud requires registration. SN-Flow has no accounts, no telemetry, and no external calls.
- **Simpler mental model.** n8n's canvas can become visually complex with many nodes. SN-Flow's `tree` command gives a clean, scannable ASCII view of the same structure.

#### Verdict
Choose n8n when you need third-party integrations and a visual editor. Choose SN-Flow when you need lightweight, portable, terminal-based automation with no infrastructure overhead.

---

### SN-Flow vs Apache Airflow

**Apache Airflow** is the industry-standard Python-based workflow orchestration platform. It is designed for data engineering pipelines — scheduling, monitoring, retrying, and coordinating complex DAGs across distributed systems.

#### Where Airflow wins
- Production-grade scheduling with cron expressions and calendar-aware triggers
- Distributed task execution across multiple workers
- Rich web UI with DAG visualization, task history, run logs, and alerting
- Native retry and failure handling with configurable backoff
- Massive ecosystem of providers (AWS, GCP, Azure, Spark, dbt, etc.)
- Role-based access control for teams

#### Where SN-Flow wins
- **No Python environment to manage.** Airflow requires Python, pip, a metadata database, a scheduler process, and optionally a message broker (Celery/Redis). SN-Flow is a single Bash script.
- **Interactive and iterative.** Airflow DAGs are Python files that must be written, saved, and parsed by the scheduler before they appear in the UI. SN-Flow lets you add a node and run it in seconds.
- **Approachable for non-data-engineers.** Airflow has a steep learning curve. SN-Flow has about 20 commands and you're running workflows in minutes.
- **No scheduler daemon.** Airflow requires a persistent scheduler process running at all times. SN-Flow is stateless between runs — invoke it when you need it.
- **Portable output.** Airflow tasks are tightly coupled to its runtime. SN-Flow can export the entire pipeline as a self-contained script.

#### Verdict
Choose Airflow for large-scale data engineering pipelines that need scheduling, retry logic, and distributed execution. Choose SN-Flow for lightweight local automation where the Airflow stack would be overkill.

---

### SN-Flow vs GitHub Actions

**GitHub Actions** is a CI/CD automation platform tightly integrated with GitHub repositories. Workflows are defined in YAML and triggered by repository events (push, PR, release, schedule).

#### Where GitHub Actions wins
- Deep integration with GitHub — triggers on commits, pull requests, issues, releases
- Massive marketplace of pre-built actions
- Free tier for public repositories
- Managed infrastructure — no servers to maintain
- Matrix builds, parallel jobs, and environment secrets management
- Native artifact storage and deployment environments

#### Where SN-Flow wins
- **Not tied to a Git repository.** GitHub Actions only runs inside a GitHub repo context. SN-Flow runs anywhere.
- **No internet required.** GitHub Actions requires a GitHub account and internet connectivity. SN-Flow is fully offline.
- **No YAML.** Actions workflows are YAML files that must be committed to the repo before they can run. SN-Flow builds workflows interactively in real time.
- **Not limited to CI/CD.** GitHub Actions is optimized for software delivery pipelines. SN-Flow is general-purpose automation — backups, monitoring scripts, data processing, anything.
- **No run limits.** GitHub Actions has usage limits on private repos. SN-Flow has no limits of any kind.
- **Runs on the local machine.** You don't need to push code to test a workflow change. Iterate locally, instantly.

#### Verdict
Choose GitHub Actions for repository-event-driven CI/CD pipelines. Choose SN-Flow for local or server automation that doesn't belong in a Git workflow.

---

### SN-Flow vs Make (Integromat)

**Make** (formerly Integromat) is a cloud-based visual automation platform with over 1,000 app integrations, designed for no-code/low-code business process automation.

#### Where Make wins
- Over 1,000 pre-built connectors (CRMs, email, spreadsheets, social media, e-commerce)
- Visual scenario builder with a polished UI
- Advanced data transformation tools (arrays, iterators, aggregators)
- Built-in error handling and rollback
- Scheduling with flexible time triggers
- No coding required for most use cases

#### Where SN-Flow wins
- **Completely free.** Make's free tier is limited to 1,000 operations/month. SN-Flow has no quotas, no tiers, and no billing.
- **No data leaves your machine.** Make processes your data on their cloud servers. SN-Flow runs entirely locally — your data stays with you.
- **No account required.** Make requires registration and is a SaaS product. SN-Flow requires nothing but Bash.
- **Works without the internet.** Make is cloud-only. SN-Flow works in fully air-gapped environments.
- **Full scripting power.** Make's transformations are limited to its built-in functions. SN-Flow gives you the full power of Bash, Python, Node.js, and Ruby inside every node.
- **No vendor lock-in.** If Make shuts down or changes pricing, your workflows are gone. SN-Flow workflows are plain files on disk you own completely.

#### Verdict
Choose Make for no-code business automation connecting SaaS apps. Choose SN-Flow when you need full control, zero cost, and local execution.

---

### SN-Flow vs Prefect

**Prefect** is a modern Python-based workflow orchestration framework designed for data and ML pipelines. It offers a Python SDK for defining flows and tasks, with a cloud or self-hosted UI for monitoring.

#### Where Prefect wins
- First-class Python — flows are just Python functions decorated with `@flow` and `@task`
- Concurrent and parallel task execution
- Rich observability — run history, state tracking, alerting, and dashboards
- Automatic retry, caching, and result persistence
- Native integrations with cloud storage, databases, and data tools (dbt, Spark, etc.)
- Managed cloud option for zero-infrastructure runs

#### Where SN-Flow wins
- **No Python environment needed.** Prefect requires Python, pip, and a Prefect server or cloud account. SN-Flow requires Bash.
- **Language-agnostic.** Prefect is Python-first. SN-Flow nodes can be written in Bash, Python, Node.js, or Ruby — mixed freely in the same workflow.
- **Interactive workflow building.** Prefect flows are Python files that must be written and registered before they run. SN-Flow lets you build and run in the same session.
- **Simpler operational model.** Prefect Cloud or a self-hosted Prefect server adds operational complexity. SN-Flow has no server — it's just files on disk.
- **Runs on any Unix system.** Prefect is not viable on minimal environments. SN-Flow runs on a $5 VPS or an Android phone.

#### Verdict
Choose Prefect for Python-native data engineering and ML pipeline orchestration. Choose SN-Flow for lightweight multi-language automation without a Python-centric stack.

---

### SN-Flow vs Zapier

**Zapier** is the most widely used no-code automation platform, connecting 6,000+ apps through a simple trigger-and-action model aimed at non-technical users.

#### Where Zapier wins
- 6,000+ app integrations — the largest library of any automation tool
- No-code — designed for non-programmers
- Reliable cloud infrastructure with 99.9% uptime SLA
- Built-in versioning, audit logs, and team collaboration
- Fastest way to connect two SaaS apps without writing a single line of code

#### Where SN-Flow wins
- **Free.** Zapier's free tier allows only 5 Zaps with 100 tasks/month. Anything beyond that requires a paid plan that can reach hundreds of dollars per month. SN-Flow is completely free, forever.
- **No data sent to third parties.** Zapier routes your data through their servers. SN-Flow keeps everything local.
- **Full scripting power.** Zapier's "Code by Zapier" step is limited and sandboxed. SN-Flow script nodes have full access to the system — files, network, environment, everything.
- **Not limited to app integrations.** Zapier is built around connecting SaaS products. SN-Flow automates anything a shell script can do — which is everything.
- **No task limits.** Zapier counts every action as a "task" and charges accordingly. SN-Flow has no concept of task limits.
- **Works offline.** Zapier is cloud-only and requires internet. SN-Flow is fully local.
- **No account, no lock-in.** You own your workflows completely. Zapier accounts, Zaps, and history disappear if you cancel.

#### Verdict
Choose Zapier if you're a non-technical user who needs to connect SaaS apps quickly with no code. Choose SN-Flow if you're a developer or power user who wants free, local, fully scriptable automation with no quotas and no middleman.

---

### Summary: When to Choose SN-Flow

SN-Flow is the right tool when:

- You are **working in a terminal** and want to stay there
- You need automation on a **minimal or constrained environment** — VPS, Raspberry Pi, Termux, air-gapped server
- You want **zero infrastructure** — no database, no server, no cloud account
- You need **multi-language scripting** in a single pipeline without a heavy framework
- You want **full data locality** — nothing leaves your machine
- You want a workflow you can **export and run anywhere** as a plain bash script
- You need something **free with no quotas, no tiers, and no billing**
- You want to **prototype quickly** without writing config files or committing code

SN-Flow is not the right tool when:

- You need **pre-built integrations** with dozens of third-party SaaS apps
- You need **distributed or parallel execution** across multiple machines
- You need **non-technical users** to build and manage workflows via a GUI
- You need **enterprise-grade scheduling, retry logic, and observability** out of the box
- Your pipelines are **data-engineering scale** (terabytes, thousands of tasks, multi-worker clusters)

---

## AI Integration Showcase

SN-Flow's script nodes give you full access to any HTTP API — including AI providers like OpenAI, Anthropic, Google Gemini, and Ollama (local LLMs). Below are complete, copy-paste-ready workflow examples that demonstrate real AI-powered pipelines built entirely inside SN-Flow.

---

### Example 1 — Ask ChatGPT a Question and Save the Answer

A simple single-shot workflow: send a prompt to OpenAI's chat API, print the response, and save it to a file.

#### Build the workflow

```
init ai_ask
add set_prompt variable bash
add ask_gpt script python3
add save_result script bash
add done text

connect start   set_prompt
connect set_prompt ask_gpt
connect ask_gpt save_result
connect save_result done
connect done end
```

#### Node bodies

```
setbody set_prompt OPENAI_API_KEY=sk-your-key-here
setbody set_prompt QUESTION="Explain what a directed acyclic graph is in two sentences."
setbody set_prompt OUTPUT_FILE=/tmp/gpt_answer.txt
```

```
edit ask_gpt
# subtype: script  lang: python3
# body (type END when done):
import os, json, urllib.request

api_key = os.environ.get("OPENAI_API_KEY", "sk-your-key-here")
question = os.environ.get("QUESTION", "Hello!")

payload = json.dumps({
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": question}]
}).encode()

req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=payload,
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
)
with urllib.request.urlopen(req) as res:
    data = json.loads(res.read())
    answer = data["choices"][0]["message"]["content"]
    print(answer)
END
```

```
setbody save_result echo "$( cat /tmp/gpt_answer.txt )" > /tmp/gpt_answer.txt && echo "Saved to /tmp/gpt_answer.txt"
```

```
setbody done Answer saved. Workflow complete.
```

#### Run it

```
run
```

#### Expected output

```
── run [ai_ask] ──────────────────────────────────────────

  ● ┌── 1. start [executing...] ✓ pass
  │   ├── 2. set_prompt [executing...] ✓ pass
  │   ├── 3. ask_gpt [executing...] ✓ pass  [python3]
  │   │   ├── output [ask_gpt]
  │   │   │  A directed acyclic graph (DAG) is a graph structure composed of
  │   │   │  nodes connected by directed edges, where no path leads back to
  │   │   │  the same node — forming no cycles. DAGs are commonly used in
  │   │   │  workflow engines, dependency resolution, and data pipelines to
  │   │   │  represent ordered sequences of tasks.
  │   │   │  ✓ exited · PID: 21034
  │   │   │  time: 843ms
  │   ├── 4. save_result [executing...] ✓ pass  [bash]
  │   │   ├── output [save_result]
  │   │   │  Saved to /tmp/gpt_answer.txt
  │   │   │  ✓ exited · PID: 21041
  │   │   │  time: 12ms
  │   └── 5. done [executing...] ✓ text
  │       ├── output [done]
  │       │  Answer saved. Workflow complete.
  └── 6. end ✓ workflow complete

  total time: 921ms
```

---

### Example 2 — AI Content Pipeline with Conditional Quality Gate

A more advanced workflow: generate a blog post intro with GPT, run a word-count decision gate, post it to a webhook if it passes, or log a warning if it's too short.

#### Workflow structure

```
init ai_pipeline

add config         variable bash
add generate       script   python3
add check_length   decision bash
add post_webhook   script   bash
add too_short      text
add log_done       text

connect start        config
connect config       generate
connect generate     check_length
connect check_length post_webhook  true
connect check_length too_short     false
connect post_webhook log_done
connect log_done     end
connect too_short    end
```

#### Node bodies

```
edit config
# subtype: variable  lang: bash
OPENAI_API_KEY=sk-your-key-here
WEBHOOK_URL=https://hooks.example.com/ingest
TOPIC="Why terminal tools are making a comeback in 2025"
MIN_WORDS=50
END
```

```
edit generate
# subtype: script  lang: python3
import os, json, urllib.request

api_key = os.environ.get("OPENAI_API_KEY", "sk-your-key-here")
topic   = os.environ.get("TOPIC", "automation")

payload = json.dumps({
    "model": "gpt-4o-mini",
    "messages": [{
        "role": "user",
        "content": f"Write a compelling 3-sentence blog post introduction about: {topic}"
    }]
}).encode()

req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=payload,
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
)
with urllib.request.urlopen(req) as res:
    data   = json.loads(res.read())
    result = data["choices"][0]["message"]["content"].strip()
    print(result)
    with open("/tmp/ai_intro.txt", "w") as f:
        f.write(result)
END
```

```
edit check_length
# subtype: decision  lang: bash
content=$(cat /tmp/ai_intro.txt 2>/dev/null)
word_count=$(echo "$content" | wc -w | tr -d ' ')
min=${MIN_WORDS:-50}
if [ "$word_count" -ge "$min" ]; then
    echo true
else
    echo false
fi
END
```

```
edit post_webhook
# subtype: script  lang: bash
content=$(cat /tmp/ai_intro.txt)
payload="{\"text\": \"$content\"}"
curl -s -X POST "$WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d "$payload" && echo "Posted to webhook successfully."
END
```

```
setbody too_short  WARNING: Generated content was too short. Skipping post.
setbody log_done   Pipeline complete. Content delivered.
```

#### Run it

```
run
```

#### Expected output (passing gate)

```
── run [ai_pipeline] ─────────────────────────────────────

  ● ┌── 1. start [executing...] ✓ pass
  │   ├── 2. config [executing...] ✓ pass
  │   ├── 3. generate [executing...] ✓ pass  [python3]
  │   │   ├── output [generate]
  │   │   │  The terminal is no longer just a developer's fallback — it's
  │   │   │  becoming the tool of choice for a new generation of engineers
  │   │   │  who value speed, composability, and full control over their
  │   │   │  environment. As GUI-based tools bloat with features nobody asked
  │   │   │  for, the humble shell is quietly staging a renaissance. In 2025,
  │   │   │  the question isn't whether you should learn the terminal — it's
  │   │   │  whether you can afford not to.
  │   │   │  ✓ exited · PID: 22811
  │   │   │  time: 1.24s
  │   ├── 4. check_length [executing...]  [decision:bash]
  │   │   │  true
  │   │   │  8ms
  │   │   └─ [true]  ◀ taken
  │   │      └── 5. post_webhook [executing...] ✓ pass  [bash]
  │   │          ├── output [post_webhook]
  │   │          │  Posted to webhook successfully.
  │   │          │  ✓ exited · PID: 22834
  │   │          │  time: 312ms
  │   └── 6. log_done [executing...] ✓ text
  │       ├── output [log_done]
  │       │  Pipeline complete. Content delivered.
  └── 7. end ✓ workflow complete

  total time: 1.58s
```

#### Expected output (failing gate — content too short)

```
  │   ├── 4. check_length [executing...]  [decision:bash]
  │   │   │  false
  │   │   │  6ms
  │   │   └─ [false]  ◀ taken
  │   │      └── 5. too_short [executing...] ✓ text
  │   │          ├── output [too_short]
  │   │          │  WARNING: Generated content was too short. Skipping post.
  └── 6. end ✓ workflow complete

  total time: 956ms
```

---

### Example 3 — Local AI with Ollama (No API Key Required)

Use a locally running Ollama instance to summarize a file — completely offline, no cloud, no API key.

> **Prerequisite:** [Ollama](https://ollama.com) installed and running with a model pulled (`ollama pull llama3`).

#### Build the workflow

```
init local_ai

add read_file   script bash
add summarize   script python3
add print_done  text

connect start     read_file
connect read_file summarize
connect summarize print_done
connect print_done end
```

#### Node bodies

```
edit read_file
# subtype: script  lang: bash
FILE="${INPUT_FILE:-/tmp/notes.txt}"
if [ ! -f "$FILE" ]; then
    echo "Creating sample notes file..."
    cat > "$FILE" << 'EOF'
Meeting notes 2025-05-12:
- Discussed Q2 roadmap with the team
- Agreed to prioritize the API refactor before adding new features
- Alice will lead the auth module; Bob handles the data layer
- Next sync scheduled for Friday at 10am
- Action items: update the ticket tracker, send recap email to stakeholders
EOF
fi
echo "File ready: $FILE"
cat "$FILE"
END
```

```
edit summarize
# subtype: script  lang: python3
import json, urllib.request

with open("/tmp/notes.txt") as f:
    content = f.read()

payload = json.dumps({
    "model": "llama3",
    "prompt": f"Summarize the following notes in one short paragraph:\n\n{content}",
    "stream": False
}).encode()

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=payload,
    headers={"Content-Type": "application/json"}
)
with urllib.request.urlopen(req) as res:
    data   = json.loads(res.read())
    summary = data.get("response", "").strip()
    print("\n── AI Summary ──────────────────────────")
    print(summary)
    print("────────────────────────────────────────")
END
```

```
setbody print_done Local AI summarization complete. No data left the machine.
```

#### Run it

```
run
```

#### Expected output

```
── run [local_ai] ────────────────────────────────────────

  ● ┌── 1. start [executing...] ✓ pass
  │   ├── 2. read_file [executing...] ✓ pass  [bash]
  │   │   ├── output [read_file]
  │   │   │  File ready: /tmp/notes.txt
  │   │   │  Meeting notes 2025-05-12:
  │   │   │  - Discussed Q2 roadmap with the team
  │   │   │  - Agreed to prioritize the API refactor...
  │   │   │  ✓ exited · PID: 31204
  │   │   │  time: 18ms
  │   ├── 3. summarize [executing...] ✓ pass  [python3]
  │   │   ├── output [summarize]
  │   │   │
  │   │   │  ── AI Summary ──────────────────────────
  │   │   │  The team met to review the Q2 roadmap and agreed to prioritize
  │   │   │  an API refactor before introducing new features. Alice will own
  │   │   │  the auth module and Bob the data layer, with a follow-up sync
  │   │   │  on Friday. Action items include updating the ticket tracker and
  │   │   │  sending a recap email to stakeholders.
  │   │   │  ────────────────────────────────────────
  │   │   │
  │   │   │  ✓ exited · PID: 31219
  │   │   │  time: 2.31s
  │   └── 4. print_done [executing...] ✓ text
  │       ├── output [print_done]
  │       │  Local AI summarization complete. No data left the machine.
  └── 5. end ✓ workflow complete

  total time: 2.34s
```

---

### Example 4 — Anthropic Claude API Integration

Use the Anthropic Claude API inside a script node to classify incoming log lines as errors, warnings, or info — then branch based on severity using a decision node.

#### Build the workflow

```
init claude_classifier

add cfg           variable bash
add read_log      script   bash
add classify      script   python3
add check_error   decision bash
add alert         script   bash
add archive       script   bash
add done          text

connect start        cfg
connect cfg          read_log
connect read_log     classify
connect classify     check_error
connect check_error  alert    true
connect check_error  archive  false
connect alert        done
connect archive      done
connect done         end
```

#### Node bodies

```
edit cfg
# subtype: variable  lang: bash
ANTHROPIC_API_KEY=sk-ant-your-key-here
LOG_FILE=/tmp/app.log
RESULT_FILE=/tmp/classification.txt
END
```

```
edit read_log
# subtype: script  lang: bash
import cfg
echo "SN-Flow started successfully" > "$LOG_FILE"
echo "Database connection timeout after 30s" >> "$LOG_FILE"
echo "Retrying connection attempt 1/3" >> "$LOG_FILE"
echo "FATAL: out of memory, process killed" >> "$LOG_FILE"
echo "Log file prepared: $LOG_FILE"
cat "$LOG_FILE"
END
```

```
edit classify
# subtype: script  lang: python3
import os, json, urllib.request

api_key  = os.environ.get("ANTHROPIC_API_KEY", "")
log_file = os.environ.get("LOG_FILE", "/tmp/app.log")
out_file = os.environ.get("RESULT_FILE", "/tmp/classification.txt")

with open(log_file) as f:
    logs = f.read()

prompt = f"""Classify the severity of these log lines.
Reply with ONLY a JSON array, one object per line, like:
[{{"line": "...", "severity": "error|warning|info"}}]

Logs:
{logs}"""

payload = json.dumps({
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 512,
    "messages": [{"role": "user", "content": prompt}]
}).encode()

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=payload,
    headers={
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json"
    }
)
with urllib.request.urlopen(req) as res:
    data   = json.loads(res.read())
    result = data["content"][0]["text"].strip()
    print(result)
    with open(out_file, "w") as f:
        f.write(result)
END
```

```
edit check_error
# subtype: decision  lang: bash
import cfg
content=$(cat "$RESULT_FILE" 2>/dev/null)
if echo "$content" | grep -qi '"severity": "error"'; then
    echo true
else
    echo false
fi
END
```

```
edit alert
# subtype: script  lang: bash
import cfg
echo "── ALERT: Errors detected in log ──────────"
grep -i '"severity": "error"' "$RESULT_FILE" | while IFS= read -r line; do
    echo "  $line"
done
echo "──────────────────────────────────────────"
echo "Alert notification sent to ops team."
END
```

```
edit archive
# subtype: script  lang: bash
import cfg
echo "No critical errors. Archiving log..."
cp "$LOG_FILE" "/tmp/archive_$(date +%Y%m%d_%H%M%S).log"
echo "Archived successfully."
END
```

```
setbody done Classification pipeline finished.
```

#### Run it

```
run
```

#### Expected output

```
── run [claude_classifier] ───────────────────────────────

  ● ┌── 1. start [executing...] ✓ pass
  │   ├── 2. cfg [executing...] ✓ pass
  │   ├── 3. read_log [executing...] ✓ pass  [bash]
  │   │   ├── output [read_log]
  │   │   │  Log file prepared: /tmp/app.log
  │   │   │  SN-Flow started successfully
  │   │   │  Database connection timeout after 30s
  │   │   │  Retrying connection attempt 1/3
  │   │   │  FATAL: out of memory, process killed
  │   │   │  ✓ exited · PID: 44201
  │   │   │  time: 11ms
  │   ├── 4. classify [executing...] ✓ pass  [python3]
  │   │   ├── output [classify]
  │   │   │  [
  │   │   │    {"line": "SN-Flow started successfully",            "severity": "info"},
  │   │   │    {"line": "Database connection timeout after 30s",   "severity": "warning"},
  │   │   │    {"line": "Retrying connection attempt 1/3",         "severity": "warning"},
  │   │   │    {"line": "FATAL: out of memory, process killed",    "severity": "error"}
  │   │   │  ]
  │   │   │  ✓ exited · PID: 44218
  │   │   │  time: 1.87s
  │   ├── 5. check_error [executing...]  [decision:bash]
  │   │   │  true
  │   │   │  9ms
  │   │   └─ [true]  ◀ taken
  │   │      └── 6. alert [executing...] ✓ pass  [bash]
  │   │          ├── output [alert]
  │   │          │  ── ALERT: Errors detected in log ──────────
  │   │          │    {"line": "FATAL: out of memory, process killed", "severity": "error"}
  │   │          │  ──────────────────────────────────────────
  │   │          │  Alert notification sent to ops team.
  │   │          │  ✓ exited · PID: 44235
  │   │          │  time: 8ms
  │   └── 7. done [executing...] ✓ text
  │       ├── output [done]
  │       │  Classification pipeline finished.
  └── 8. end ✓ workflow complete

  ────────────────────────────────────────
  total time: 1.96s
  ────────────────────────────────────────
```

---

### AI Integration Summary

| Provider | Protocol | Auth | Example Use |
|---|---|---|---|
| **OpenAI** (GPT-4o, GPT-4o-mini) | REST / HTTPS | `Authorization: Bearer sk-...` | Text generation, summarization, Q&A |
| **Anthropic** (Claude) | REST / HTTPS | `x-api-key: sk-ant-...` | Classification, reasoning, code review |
| **Google Gemini** | REST / HTTPS | `?key=AIza...` | Multimodal, translation, structured output |
| **Ollama** (local LLMs) | REST / HTTP | None (local) | Offline summarization, classification, chat |
| **Hugging Face** Inference API | REST / HTTPS | `Authorization: Bearer hf_...` | Open-source models, embeddings, NLP tasks |

Any AI provider that exposes an HTTP API can be called from a SN-Flow script node. The pattern is always the same: build a JSON payload, send it with `curl` (bash) or `urllib`/`requests` (python3), parse the response, and pass the result downstream — either as a file, an environment variable, or stdout output that the next node reads.

---

## Getting Started

See [README.md](README.md) for the full command reference, node type documentation, and worked examples.

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
