#!/usr/bin/env bash
# ╔══════════════════════════════════════════════╗
# ║   flowM.sh  —  Flow Manager                  ║
# ║   Execution Engine · Tree View · REPL        ║
# ╚══════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/UIM"
source "$SCRIPT_DIR/commandM.sh"

# ═══════════════════════════════════════════════
# ROOT DETECTION
# ═══════════════════════════════════════════════

_IS_ROOT=0
_check_root() {
  if [[ "$EUID" -eq 0 ]] || id | grep -q "uid=0"; then
    _IS_ROOT=1
  elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    _IS_ROOT=1
  else
    _IS_ROOT=0
  fi
}
_check_root

# ═══════════════════════════════════════════════
# RUN — TREE-STYLE EXECUTION ENGINE
# ═══════════════════════════════════════════════

_visited=()
_run_counter=0

# Execute a node's body and show output in formatted style
_exec_node() {
  local id="$1" sub="$2" lang="$3" body="$4" prefix="$5"

  if [[ "$sub" == "passthrough" || -z "$sub" || -z "$body" ]]; then
    return
  fi

  _print_output_block() {
    local label="$1"; shift
    local lines=("$@")
    echo -e "${prefix}${GY}├ output ${WD}[${OR}${label}${WD}]${RS}"
    for oline in "${lines[@]}"; do
      echo -e "${prefix}${GY}│${RS} ${WD}${oline}${RS}"
    done
  }

  if [[ "$sub" == "script" && -n "$body" ]]; then
    local log_file="$DATA/${id}_bg.log"
    > "$log_file"

    local is_bg=0
    case "$lang" in
      bash|sh)        echo "$body" | grep -qE '^\s*(while|for|until)\b'      && is_bg=1 ;;
      python|python3) echo "$body" | grep -qE '^\s*(while|for)\b'            && is_bg=1 ;;
      node|nodejs|js) echo "$body" | grep -qE '(while\s*\(|for\s*\()'       && is_bg=1 ;;
      ruby)           echo "$body" | grep -qE '(while\s|\.each\s|\.times)'   && is_bg=1 ;;
      *)              echo "$body" | grep -qE '\b(while|for|until)\b'         && is_bg=1 ;;
    esac
    local word_count
    word_count=$(echo "$body" | wc -w)
    [[ $word_count -le 3 ]] && is_bg=1

    case "$lang" in
      bash|sh)        bash    -c "$body" > "$log_file" 2>&1 & ;;
      python|python3) python3 -u -c "$body" > "$log_file" 2>&1 & ;;
      node|nodejs|js) node    -e "$body" > "$log_file" 2>&1 & ;;
      ruby)           ruby    -e "$body" > "$log_file" 2>&1 & ;;
      *)              bash    -c "$body" > "$log_file" 2>&1 & ;;
    esac
    local pid=$!

    if [[ $is_bg -eq 1 ]]; then
      local waited=0
      while [[ $waited -lt 30 ]]; do
        sleep 0.1; waited=$((waited+1))
        [[ $(wc -l < "$log_file" 2>/dev/null) -ge 1 ]] && break
      done
      local bg_lines=()
      if [[ -s "$log_file" ]]; then
        local shown=0
        while IFS= read -r oline; do
          bg_lines+=("$oline"); shown=$((shown+1))
          [[ $shown -ge 5 ]] && break
        done < "$log_file"
      fi
      bg_lines+=("${GY}⟳ running in background · PID: $pid${RS}")
      bg_lines+=("${GY}  log: ~/.flowterm/${id}_bg.log${RS}")
      disown $pid
      _print_output_block "$id" "${bg_lines[@]}"
    else
      wait $pid 2>/dev/null; disown $pid 2>/dev/null
      local bg_lines=()
      if [[ -s "$log_file" ]]; then
        local shown=0
        while IFS= read -r oline; do
          bg_lines+=("$oline"); shown=$((shown+1))
          [[ $shown -ge 5 ]] && break
        done < "$log_file"
      fi
      bg_lines+=("${GY}✓ exited · PID: $pid${RS}")
      _print_output_block "$id" "${bg_lines[@]}"
    fi

  elif [[ "$sub" == "text" && -n "$body" ]]; then
    local text_lines=()
    while IFS= read -r tline; do text_lines+=("$tline"); done <<< "$body"
    _print_output_block "$id" "${text_lines[@]}"
  fi
}


run_node() {
  local id="$1" prefix="$2" branch="$3" is_last="$4"

  for v in "${_visited[@]}"; do [[ "$v" == "$id" ]] && return; done
  _visited+=("$id")

  node_exists "$id" || { echo -e "${prefix}${branch}${RE}✗ '$id' not found${RS}"; return; }

  local type sub lang body
  type=$(node_type   "$id"); sub=$(node_subtype "$id")
  lang=$(node_lang   "$id"); body=$(node_body   "$id")

  case "$type" in
    start)
      _run_counter=$((_run_counter+1))
      echo -e "  ${prefix}${branch}${GR}●${RS} ${GY}┌──${RS} ${GR}${BD}${_run_counter}.${RS} ${OR}${BD}${id}${RS} ${GY}[${RS}${BL}executing...${RS}${GY}]${RS} ${GR}✓ pass${RS}"
      ;;
    end) return ;;
    command)
      if [[ "$sub" == "decision" ]]; then
        # ── decision node ──────────────────────────
        _run_counter=$((_run_counter+1))
        echo -e "${prefix}${branch}${GR}${BD}${_run_counter}.${RS} ${CY}${BD}${id}${RS} ${GY}[${RS}${BL}executing...${RS}${GY}]${RS}  ${GY}[${CY}decision${GY}:${BL}${lang}${GY}]${RS}"

        local child_prefix_d
        if [[ "$is_last" == "1" ]]; then child_prefix_d="${prefix}    "
        else child_prefix_d="${prefix}${GY}│${RS}   "; fi

        # evaluate condition and capture raw output
        local result raw_output
        local log_file="$DATA/${id}_decision.log"
        > "$log_file"
        case "$lang" in
          bash|sh)        bash    -c "$body" > "$log_file" 2>&1 ;;
          python|python3) python3 -u -c "$body" > "$log_file" 2>&1 ;;
          node|nodejs|js) node    -e "$body" > "$log_file" 2>&1 ;;
          ruby)           ruby    -e "$body" > "$log_file" 2>&1 ;;
          *)              bash    -c "$body" > "$log_file" 2>&1 ;;
        esac
        raw_output=$(cat "$log_file" 2>/dev/null | tr -d '\r' | xargs)
        if [[ "$raw_output" == "true" ]]; then result="true"
        else result="false"; fi

        # show script output
        echo -e "${child_prefix_d}${GY}│${RS} ${WD}${raw_output}${RS}"

        local true_kids=() false_kids=()
        mapfile -t true_kids  < <(conn_out "$id" "true")
        mapfile -t false_kids < <(conn_out "$id" "false")

        # ── show only the taken branch ────
        if [[ "$result" == "true" ]]; then
          echo -e "${child_prefix_d}${GY}└─${RS} ${GR}[true]${RS}  ${GR}◀ taken${RS}"
          local tk_prefix="${child_prefix_d}   "
          local ti=0 tn=${#true_kids[@]}
          for tk in "${true_kids[@]}"; do
            local tk_last=0 tk_branch="${GY}└─${RS} "
            [[ $((ti+1)) -eq $tn ]] && tk_last=1
            run_node "$tk" "$tk_prefix" "$tk_branch" "$tk_last"
            ti=$((ti+1))
          done
          [[ ${#true_kids[@]} -eq 0 ]] && echo -e "${child_prefix_d}   ${GY}└─ ${GL}(no true branch)${RS}"
        else
          echo -e "${child_prefix_d}${GY}└─${RS} ${RE}[false]${RS}  ${RE}◀ taken${RS}"
          local fk_prefix="${child_prefix_d}   "
          local fi=0 fn=${#false_kids[@]}
          for fk in "${false_kids[@]}"; do
            local fk_last=0 fk_branch="${GY}└─${RS} "
            [[ $((fi+1)) -eq $fn ]] && fk_last=1
            run_node "$fk" "$fk_prefix" "$fk_branch" "$fk_last"
            fi=$((fi+1))
          done
          [[ ${#false_kids[@]} -eq 0 ]] && echo -e "${child_prefix_d}   ${GY}└─ ${GL}(no false branch)${RS}"
        fi
        return
        # ── end decision ──────────────────
      fi

      local status_str=""
      if [[ "$sub" == "passthrough" || -z "$sub" ]]; then
        status_str="${GR}✓ pass${RS}"
      elif [[ "$sub" == "script" ]]; then
        status_str="${GR}✓ pass${RS}  ${GY}[${BL}${lang}${GY}]${RS}"
      elif [[ "$sub" == "text" ]]; then
        status_str="${GR}✓ text${RS}"
      else
        status_str="${GR}✓ pass${RS}"
      fi
      _run_counter=$((_run_counter+1))
      echo -e "${prefix}${branch}${GR}${BD}${_run_counter}.${RS} ${WH}${BD}${id}${RS} ${GY}[${RS}${BL}executing...${RS}${GY}]${RS} ${status_str}"
      ;;
  esac

  local child_prefix
  if [[ "$is_last" == "1" ]]; then child_prefix="${prefix}    "
  else child_prefix="${prefix}${GY}│${RS}   "; fi

  _exec_node "$id" "$sub" "$lang" "$body" "$child_prefix"

  local children=()
  mapfile -t children < <(conn_out "$id")
  local n=${#children[@]}

  for (( i=0; i<n; i++ )); do
    local next="${children[$i]}"
    local child_is_last=0
    local child_branch="${GY}\u251C\u2500\u2500 ${RS}"
    if [[ $((i+1)) -eq $n ]]; then
      child_is_last=1; child_branch="${GY}\u2514\u2500\u2500 ${RS}"
    fi
    [[ "$type" == "start" && $i -gt 0 ]] && echo -e "${child_prefix}${GY}\u2502${RS}"
    run_node "$next" "$child_prefix" "$child_branch" "$child_is_last"
  done
}

cmd_run() {
  hdr "run [$PROJ]"
  node_exists "start" || { err "no start node — use: init $PROJ"; return; }
  echo ""
  _visited=(); _visited+=("end"); _run_counter=0
  run_node "start" "" "" "1"
  if node_exists "end"; then
    _run_counter=$((_run_counter+1))
    echo -e "    ${GY}\u2514\u2500\u2500 ${RS}${GR}${BD}${_run_counter}.${RS} ${GR}${OR}end${RS} ${GR}✓ workflow complete${RS}"
    echo ""
  fi
}


# ═══════════════════════════════════════════════
# RUNBG — FULLY BACKGROUND WORKFLOW EXECUTION
# ═══════════════════════════════════════════════
#
#  Each background run gets a unique session dir:
#    ~/.flowterm/runs/<proj>_<timestamp>/
#      meta              — proj, run_id, started, pid
#      run.log           — top-level execution log
#      workflow.status   — RUNNING | COMPLETE | ERROR
#      node_<id>.log     — per-node stdout/stderr
#      node_<id>.status  — PENDING | RUNNING | DONE | ERROR:<code>
#      connections.snap  — snapshot of connections at launch
#      <id>.node.snap    — snapshot of each node file at launch
#
#  The global registry is:
#    ~/.flowterm/runs/.registry  — one run_id per line
# ═══════════════════════════════════════════════

_bg_exec_node() {
  local id="$1" sub="$2" lang="$3" body="$4" log_dir="$5"
  local node_log="$log_dir/node_${id}.log"

  echo "[$(date '+%H:%M:%S')] START node: $id  sub=$sub  lang=$lang" >> "$node_log"
  echo "RUNNING" > "$log_dir/node_${id}.status"

  if [[ "$sub" == "passthrough" || -z "$sub" || -z "$body" ]]; then
    echo "[$(date '+%H:%M:%S')] PASS (passthrough / no body)" >> "$node_log"
    echo "DONE" > "$log_dir/node_${id}.status"
    return
  fi

  if [[ "$sub" == "script" && -n "$body" ]]; then
    echo "RUNNING" > "$log_dir/node_${id}.status"
    echo "[$(date '+%H:%M:%S')] EXEC script [$lang]" >> "$node_log"
    case "$lang" in
      bash|sh)        bash    -c "$body" >> "$node_log" 2>&1 ;;
      python|python3) python3 -u -c "$body" >> "$node_log" 2>&1 ;;
      node|nodejs|js) node    -e "$body" >> "$node_log" 2>&1 ;;
      ruby)           ruby    -e "$body" >> "$node_log" 2>&1 ;;
      *)              bash    -c "$body" >> "$node_log" 2>&1 ;;
    esac
    local exit_code=$?
    echo "[$(date '+%H:%M:%S')] EXIT code=$exit_code" >> "$node_log"
    if [[ $exit_code -eq 0 ]]; then
      echo "DONE" > "$log_dir/node_${id}.status"
    else
      echo "ERROR:$exit_code" > "$log_dir/node_${id}.status"
      echo "WORKFLOW_ERROR:$id:$exit_code" >> "$log_dir/run.log"
    fi

  elif [[ "$sub" == "text" && -n "$body" ]]; then
    echo "[$(date '+%H:%M:%S')] TEXT output:" >> "$node_log"
    echo "$body" >> "$node_log"
    echo "DONE" > "$log_dir/node_${id}.status"
  fi
}

_bg_run_traversal() {
  local log_dir="$1"
  local _bgv=()

  _bgvisit() {
    local id="$1"
    for v in "${_bgv[@]}"; do [[ "$v" == "$id" ]] && return; done
    _bgv+=("$id")

    [[ "$id" == "end" ]] && {
      echo "[$(date '+%H:%M:%S')] REACHED end node" >> "$log_dir/run.log"
      echo "[$(date '+%H:%M:%S')] PASS (end)" >> "$log_dir/node_end.log"
      echo "DONE" > "$log_dir/node_end.status"
      return
    }

    if ! node_exists "$id"; then
      echo "[$(date '+%H:%M:%S')] ERROR: node '$id' missing" >> "$log_dir/run.log"
      echo "ERROR:missing" > "$log_dir/node_${id}.status"
      return
    fi

    local type sub lang body
    type=$(node_type   "$id"); sub=$(node_subtype "$id")
    lang=$(node_lang   "$id"); body=$(node_body   "$id")

    echo "PENDING" > "$log_dir/node_${id}.status"
    echo "[$(date '+%H:%M:%S')] NODE $id  type=$type" >> "$log_dir/run.log"

    _bg_exec_node "$id" "$sub" "$lang" "$body" "$log_dir"

    # check if this node errored and stop traversal on error
    local ns
    ns=$(cat "$log_dir/node_${id}.status" 2>/dev/null)
    if [[ "$ns" == ERROR* ]]; then
      echo "[$(date '+%H:%M:%S')] HALT: node '$id' failed, stopping" >> "$log_dir/run.log"
      echo "ERROR:node_$id" > "$log_dir/workflow.status"
      return
    fi

    mapfile -t kids < <(conn_out "$id")
    for k in "${kids[@]}"; do _bgvisit "$k"; done
  }

  _bgvisit "start"

  # only mark complete if not already in error state
  local ws
  ws=$(cat "$log_dir/workflow.status" 2>/dev/null)
  if [[ "$ws" == "RUNNING" ]]; then
    echo "COMPLETE" > "$log_dir/workflow.status"
    echo "[$(date '+%H:%M:%S')] WORKFLOW COMPLETE" >> "$log_dir/run.log"
  fi
}

cmd_runbg() {
  node_exists "start" || { err "no start node — use: init $PROJ"; return; }

  # unique session ID
  local run_id="${PROJ}_$(date '+%Y%m%d_%H%M%S')"
  local log_dir="$DATA/runs/$run_id"
  mkdir -p "$log_dir"

  # snapshot current state so monitor can read node names even if edited later
  cp "$CONNS" "$log_dir/connections.snap"
  for nf in "$NODES"/*.node; do
    [[ -f "$nf" ]] && cp "$nf" "$log_dir/$(basename "$nf").snap"
  done

  # write metadata file
  {
    echo "proj=$PROJ"
    echo "run_id=$run_id"
    echo "started=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "pid=0"
  } > "$log_dir/meta"

  echo "RUNNING" > "$log_dir/workflow.status"

  # register in global registry
  echo "$run_id" >> "$DATA/runs/.registry"

  # launch fully detached
  # NOTE: source UIM unconditionally resets PROJ to "project1" at the bottom,
  # so we capture the correct project name before forking the subshell.
  local _bg_proj="$PROJ"
  (
    source "$SCRIPT_DIR/UIM"
    use_proj "$_bg_proj"
    _bg_run_traversal "$log_dir"
  ) >> "$log_dir/run.log" 2>&1 &

  local bg_pid=$!
  disown $bg_pid

  # update PID in meta
  sed -i "s/^pid=.*/pid=$bg_pid/" "$log_dir/meta" 2>/dev/null

  hdr "runbg [$PROJ]"
  echo ""
  ok "workflow launched fully in background"
  info "run ID  : ${OR}${run_id}${RS}"
  info "PID     : ${GL}${bg_pid}${RS}"
  info "logs    : ${GL}${log_dir}${RS}"
  echo ""
  info "monitor : ${OR}bash ${SCRIPT_DIR}/flowmon.sh${RS}"
  info "         use ${OR}logs <run_id>${RS} and ${OR}stop <run_id>${RS} inside monitor"
  echo ""
}

# ═══════════════════════════════════════════════
# SORT
# ═══════════════════════════════════════════════

cmd_sort() {
  require_init || return
  local parent="$1"
  [[ -z "$parent" ]] && { err "usage: sort <node>"; return; }
  node_exists "$parent" || { err "node '$parent' not found"; return; }

  local children=()
  mapfile -t children < <(conn_out "$parent")
  local n=${#children[@]}

  if [[ $n -eq 0 ]]; then warn "node '$parent' has no children to sort"; return; fi
  if [[ $n -eq 1 ]]; then warn "node '$parent' only has one child — nothing to sort"; return; fi

  hdr "sort children of [${parent}]"
  echo ""
  local i
  for (( i=0; i<n; i++ )); do
    echo -e "  ${GR}${BD}$((i+1)).${RS} ${OR}${children[$i]}${RS}"
  done
  echo ""
  echo -e "  ${GL}enter new order as numbers separated by spaces${RS}"
  echo -e "  ${GY}example: 3 1 2${RS}"
  echo ""
  echo -ne "  ${OR}${BD}▶${RS} "
  read -r order_input

  local new_order=(); read -ra picks <<< "$order_input"
  if [[ ${#picks[@]} -ne $n ]]; then err "expected $n numbers, got ${#picks[@]}"; return; fi

  local used=() valid=1
  for pick in "${picks[@]}"; do
    if ! [[ "$pick" =~ ^[0-9]+$ ]] || [[ $pick -lt 1 || $pick -gt $n ]]; then
      err "invalid number: $pick  (must be 1–$n)"; valid=0; break
    fi
    for u in "${used[@]}"; do
      if [[ "$u" == "$pick" ]]; then err "duplicate number: $pick"; valid=0; break 2; fi
    done
    used+=("$pick"); new_order+=("${children[$((pick-1))]}")
  done
  [[ $valid -eq 0 ]] && return

  for child in "${children[@]}"; do conn_remove "$parent" "$child"; done
  for child in "${new_order[@]}"; do conn_add "$parent" "$child" 2>/dev/null; done

  ok "sorted children of ${OR}${parent}${RS}:"
  for (( i=0; i<${#new_order[@]}; i++ )); do
    echo -e "  ${GR}${BD}$((i+1)).${RS} ${OR}${new_order[$i]}${RS}"
  done
  echo ""
}

# ═══════════════════════════════════════════════
# TREE VIEW
# ═══════════════════════════════════════════════

_tree_visited=()

tree_node() {
  local id="$1" prefix="$2" is_last="$3"
  for r in "${_tree_visited[@]}"; do [[ "$r" == "$id" ]] && return; done
  _tree_visited+=("$id")

  local type sub lang preview
  type=$(node_type "$id"); sub=$(node_subtype "$id")
  lang=$(node_lang "$id"); preview=$(node_body "$id" | head -1 | cut -c1-38)

  local branch="├─" child_pre="${prefix}│  "
  [[ "$is_last" == "1" ]] && branch="└─" && child_pre="${prefix}   "
  [[ -z "$prefix" ]] && branch="" && child_pre="   "

  local tag_s tag_e
  case "$type" in
    start)   tag_s="${OR}${BD}"; tag_e="${RS}" ;;
    end)     tag_s="${GR}";      tag_e="${RS}" ;;
    command) tag_s="${WH}";      tag_e="${RS}" ;;
    *)       tag_s="${GL}";      tag_e="${RS}" ;;
  esac

  local badge=""
  [[ "$sub" == "script"   ]] && badge=" ${GY}[${BL}${lang}${GY}]${RS}"
  [[ "$sub" == "text"     ]] && badge=" ${GY}[${WD}text${GY}]${RS}"
  [[ "$sub" == "decision" ]] && badge=" ${GY}[${CY}decision${GY}:${BL}${lang}${GY}]${RS}"

  local outs arrows=""
  mapfile -t outs < <(conn_out "$id")
  for o in "${outs[@]}"; do arrows+=" ${OD}→${RS}${GL}${o}${RS}"; done

  echo -e "  ${GY}${prefix}${branch}${RS} ${tag_s}[${id}]${tag_e}${badge}${arrows}"
  [[ -n "$preview" ]] && echo -e "  ${GY}${child_pre}│${RS}  ${DM}${WD}${preview}${RS}"

  local kids=()
  mapfile -t kids < <(conn_out "$id")
  local nk=${#kids[@]}
  for (( i=0; i<nk; i++ )); do
    local last=0; [[ $((i+1)) -eq $nk ]] && last=1
    tree_node "${kids[$i]}" "$child_pre" "$last"
  done
}

cmd_tree() {
  hdr "workflow tree [$PROJ]"
  echo ""
  local all=()
  mapfile -t all < <(node_list)
  [[ ${#all[@]} -eq 0 ]] && { info "empty — try: init $PROJ"; echo ""; return; }

  _tree_visited=()
  node_exists "start" && tree_node "start" "" "1"
  for n in "${all[@]}"; do
    local seen=0
    for r in "${_tree_visited[@]}"; do [[ "$r" == "$n" ]] && seen=1; done
    [[ $seen -eq 0 ]] && tree_node "$n" "" "1"
  done
  echo ""
}

# ═══════════════════════════════════════════════
# MAIN REPL
# ═══════════════════════════════════════════════

main() {
  banner
  info "type ${OR}help${RS}${WD} for commands"
  info "project: ${OR}${PROJ}${RS}  |  data: ${GL}$DATA/$PROJ${RS}"
  if [[ $_IS_ROOT -eq 1 ]]; then
    echo -e "  ${OR}⬡${RS}  ${OR}root access detected — sudo commands available in script nodes${RS}"
  else
    echo -e "  ${BL}❄${RS}  ${BL}Non rooted device is also compatible for workflow environment${RS}"
  fi
  echo ""

  while true; do
    prompt_line
    read -r input
    [[ -z "$input" ]] && continue

    local cmd arg1 arg2 rest
    read -r cmd arg1 arg2 rest <<< "$input"

    case "$cmd" in
      clear)          cmd_clear ;;
      init)           cmd_init "$arg1" ;;
      switch)         cmd_switch "$arg1" ;;
      projects)       cmd_projects ;;
      rmproj)         cmd_rmproj "$arg1" ;;
      add)            cmd_add "$arg1" "$arg2" "$rest" ;;
      setbody)        cmd_setbody "$arg1" "$arg2 $rest" ;;
      connect)        cmd_connect "$arg1" "$arg2" "$rest" ;;
      disconnect)     cmd_disconnect "$arg1" "$arg2" ;;
      edit)           cmd_edit "$arg1" ;;
      show)           cmd_show "$arg1" ;;
      list)           cmd_list "$arg1" ;;
      sort)           cmd_sort "$arg1" ;;
      tree)           cmd_tree ;;
      run)            cmd_run ;;
      runbg)          cmd_runbg ;;
      delete)         cmd_delete "$arg1" ;;
      export)         cmd_export "$arg1" ;;
      reset)          cmd_reset ;;
      help|h|\?)      cmd_help ;;
      exit|quit|q)    echo -e "\n  ${GY}bye.${RS}\n"; exit 0 ;;
      *)              err "unknown command: $cmd  (type help)" ;;
    esac
  done
}

main "$@"
