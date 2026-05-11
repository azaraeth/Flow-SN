#!/usr/bin/env bash
# ╔══════════════════════════════════════════════╗
# ║   commandM.sh  —  Command Manager            ║
# ║   CRUD · Projects · Export · Help            ║
# ╚══════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/UIM"

# ═══════════════════════════════════════════════
# NODE MANAGEMENT COMMANDS
# ═══════════════════════════════════════════════

cmd_init() {
  local name="${1:-project1}"
  validate_node_name "$name" || return
  use_proj "$name"
  node_exists "start" && { warn "project '$PROJ' already initialized"; return; }
  node_save "start" "start"   "passthrough" "-" ""
  node_save "end"   "end"     "passthrough" "-" ""
  echo "$PROJ" >> "$DATA/.projects"
  ok "initialized project: ${OR}${PROJ}${RS}"
  info "nodes created: ${OR}start${RS} + ${GR}end${RS}"
}

cmd_add() {
  require_init || return
  local name="$1" sub="${2:-passthrough}" lang="${3:-}"
  [[ -z "$name" ]] && { err "usage: add <name> [passthrough|text|script|decision|variable|sleep] [lang|duration]"; return; }
  validate_node_name "$name" || return
  node_exists "$name" && { err "node '$name' exists"; return; }
  if [[ "$sub" == "decision" ]]; then
    # decision nodes always have a language for their condition script
    [[ -z "$lang" ]] && lang="bash"
    node_save "$name" "command" "decision" "$lang" ""
    ok "added: ${CY}${name}${RS}  ${GY}[${CY}decision${GY}:${BL}${lang}${GY}]${RS}"
    info "set condition with: setbody $name <code>"
    info "connect branches : connect $name <node> true / false"
  elif [[ "$sub" == "variable" ]]; then
    # variable nodes store reusable code (assignments, functions, etc.)
    [[ -z "$lang" ]] && lang="bash"
    node_save "$name" "command" "variable" "$lang" ""
    ok "added: ${MA}${name}${RS}  ${GY}[${MA}variable${GY}:${BL}${lang}${GY}]${RS}"
    info "set body with: setbody $name <code>"
    info "use in scripts  : import $name"
  elif [[ "$sub" == "sleep" ]]; then
    # sleep nodes pause execution for a given duration (seconds, int/float)
    local bdy="${lang:-0}"
    node_save "$name" "command" "sleep" "-" "$bdy"
    ok "added: ${OR}${name}${RS}  ${GY}[sleep: ${bdy}s${GY}]${RS}"
    info "adjust duration: setbody $name <seconds>"
  else
    # validate sub type
    case "$sub" in
      passthrough|text|script) ;;
      *) err "unknown subtype '$sub' — use: passthrough|text|script|decision|variable|sleep"; return ;;
    esac
    [[ "$sub" != "script" ]] && lang="-"
    node_save "$name" "command" "$sub" "$lang" ""
    if [[ "$sub" == "script" ]]; then
      ok "added: ${OR}${name}${RS}  ${GY}[${sub}:${BL}${lang}${GY}]${RS}"
    else
      ok "added: ${OR}${name}${RS}  ${GY}[${sub}${GY}]${RS}"
    fi
    info "set body with: setbody $name <content>"
  fi
}

cmd_setbody() {
  require_init || return
  local name="$1"; shift
  local body="$*"
  node_exists "$name" || { err "node '$name' not found"; return; }
  local type sub lang
  type=$(node_type "$name"); sub=$(node_subtype "$name"); lang=$(node_lang "$name")
  node_save "$name" "$type" "$sub" "$lang" "$body"
  ok "body set: $name"
}

cmd_connect() {
  require_init || return
  local f="$1" t="$2" branch="${3:-}"
  [[ -z "$f" || -z "$t" ]] && { err "usage: connect <from> <to> [true|false]"; return; }
  node_exists "$f" || { err "node '$f' not found"; return; }
  node_exists "$t" || { err "node '$t' not found"; return; }
  # validate branch tag if this is a decision node
  local fsub; fsub=$(node_subtype "$f")
  if [[ "$fsub" == "decision" ]]; then
    [[ "$branch" != "true" && "$branch" != "false" ]] && {
      err "decision node '$f' requires a branch: connect $f $t true|false"; return
    }
  elif [[ -n "$branch" ]]; then
    warn "branch tag '$branch' ignored — '$f' is not a decision node"
    branch=""
  fi
  if conn_add "$f" "$t" "$branch"; then
    local blabel=""
    [[ -n "$branch" ]] && blabel="  ${GY}[$([ "$branch" = "true" ] && echo "${GR}true" || echo "${RE}false")${GY}]${RS}"
    ok "connected: ${OR}${f}${RS} → ${OR}${t}${RS}${blabel}"
  fi
}

cmd_disconnect() {
  require_init || return
  local f="$1" t="$2"
  [[ -z "$f" || -z "$t" ]] && { err "usage: disconnect <from> <to>"; return; }
  node_exists "$f" || { err "node '$f' not found"; return; }
  node_exists "$t" || { err "node '$t' not found"; return; }
  if conn_remove "$f" "$t"; then
    ok "disconnected: $f → $t"
  fi
}

cmd_show() {
  require_init || return
  local name="$1"
  [[ -z "$name" ]] && { err "usage: show <name>"; return; }
  node_exists "$name" || { err "not found: $name"; return; }

  hdr "node: $name"
  local type sub lang body
  type=$(node_type "$name"); sub=$(node_subtype "$name")
  lang=$(node_lang "$name"); body=$(node_body "$name")

  echo -e "  ${GL}type     ${RS}${OR}${type}${RS}"
  echo -e "  ${GL}subtype  ${RS}${WH}${sub}${RS}"
  if [[ "$sub" == "decision" ]]; then
    echo -e "  ${GL}lang     ${RS}${BL}${lang}${RS}"
    local tb fb
    tb=$(conn_out "$name" "true" | tr '\n' ' ')
    fb=$(conn_out "$name" "false" | tr '\n' ' ')
    echo -e "  ${GL}true →   ${RS}${GR}${tb:-none}${RS}"
    echo -e "  ${GL}false →  ${RS}${RE}${fb:-none}${RS}"
  elif [[ "$sub" == "script" || "$sub" == "variable" ]]; then
    echo -e "  ${GL}lang     ${RS}${BL}${lang}${RS}"
  fi

  # show imports used by this node (script/decision/variable)
  if [[ "$sub" == "script" || "$sub" == "decision" || "$sub" == "variable" ]]; then
    local imports=()
    while IFS= read -r iline; do
      if [[ "$iline" =~ ^[[:space:]]*import[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
        imports+=("${BASH_REMATCH[1]}")
      fi
    done <<< "$body"
    if [[ ${#imports[@]} -gt 0 ]]; then
      echo -e "  ${GL}imports  ${RS}${MA}${imports[*]}${RS}"
    fi
  fi

  local outs ins
  mapfile -t outs < <(conn_out "$name")
  mapfile -t ins  < <(conn_in  "$name")
  echo -e "  ${GL}out      ${RS}${OD}${outs[*]:-none}${RS}"
  echo -e "  ${GL}in       ${RS}${GL}${ins[*]:-none}${RS}"

  if [[ -n "$body" ]]; then
    div
    echo -e "  ${GL}body:${RS}"
    while IFS= read -r l; do
      echo -e "  ${GY}│${RS}  ${WD}${l}${RS}"
    done <<< "$body"
  fi
  echo ""
}

cmd_list() {
  if [[ "$1" == "--all" || "$1" == "-a" ]]; then
    hdr "all projects"
    echo ""
    if [[ ! -f "$DATA/.projects" ]]; then
      info "no projects"
      echo ""; return
    fi
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      local saved_PROJ="$PROJ"
      use_proj "$p"
      local all=()
      mapfile -t all < <(node_list)
      if [[ ${#all[@]} -eq 0 ]]; then
        hdr "$p [empty]"
      else
        hdr "$p $( [[ "$p" == "$saved_PROJ" ]] && echo -e "(current)" )"
        for n in "${all[@]}"; do
          local type sub lang badge=""
          type=$(node_type "$n"); sub=$(node_subtype "$n"); lang=$(node_lang "$n")
          [[ "$sub" == "script" ]] && badge="${GY}[${BL}${lang}${GY}]${RS}"
          [[ "$sub" == "text"   ]] && badge="${GY}[${WD}text${GY}]${RS}"
          [[ "$sub" == "variable" ]] && badge="${GY}[${MA}variable${GY}:${BL}${lang}${GY}]${RS}"
          [[ "$sub" == "sleep"   ]] && badge="${GY}[${CY}sleep: ${body}s${GY}]${RS}"
          printf "    ${OR}%-18s${RS} ${GL}%-14s${RS} %b\n" "$n" "$type" "$badge"
        done
        if [[ -s "$CONNS" ]]; then
          while IFS=' ' read -r f t branch; do
            [[ -z "$f" ]] && continue
            local blabel=""
            [[ "$branch" == "true"  ]] && blabel=" ${GR}[true]${RS}"
            [[ "$branch" == "false" ]] && blabel=" ${RE}[false]${RS}"
            echo -e "    ${OR}${f}${RS} ${GY}→${RS} ${OD}${t}${RS}${blabel}"
          done < "$CONNS"
        fi
      fi
      use_proj "$saved_PROJ"
      echo ""
    done < "$DATA/.projects"
    return
  fi

  local nodes=()
  mapfile -t nodes < <(node_list)
  if [[ ${#nodes[@]} -eq 0 ]]; then
    hdr "nodes [empty]"
    info "none — try: init $PROJ"; echo ""; return
  fi
  hdr "nodes [$PROJ]"
  for n in "${nodes[@]}"; do
    local type sub lang badge=""
    type=$(node_type "$n"); sub=$(node_subtype "$n"); lang=$(node_lang "$n")
    [[ "$sub" == "script"   ]] && badge="${GY}[${BL}${lang}${GY}]${RS}"
    [[ "$sub" == "text"     ]] && badge="${GY}[${WD}text${GY}]${RS}"
    [[ "$sub" == "decision" ]] && badge="${GY}[${CY}decision${GY}:${BL}${lang}${GY}]${RS}"
    [[ "$sub" == "variable" ]] && badge="${GY}[${MA}variable${GY}:${BL}${lang}${GY}]${RS}"
    printf "  ${OR}%-18s${RS} ${GL}%-14s${RS} %b\n" "$n" "$type" "$badge"
  done

  echo ""
  hdr "connections [$PROJ]"
  if [[ ! -s "$CONNS" ]]; then
    info "none"
  else
    while IFS=' ' read -r f t branch; do
      [[ -z "$f" ]] && continue
      local blabel=""
      if [[ "$branch" == "true" ]];  then blabel=" ${GR}[true]${RS}"
      elif [[ "$branch" == "false" ]]; then blabel=" ${RE}[false]${RS}"
      fi
      echo -e "  ${OR}${f}${RS} ${GY}→${RS} ${OD}${t}${RS}${blabel}"
    done < "$CONNS"
  fi
  echo ""
}

cmd_delete() {
  require_init || return
  local name="$1"
  [[ -z "$name" ]] && { err "usage: delete <name>"; return; }
  node_exists "$name" || { err "not found: $name"; return; }
  echo -ne "  ${OD}delete '${name}'? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }
  node_delete "$name"
  ok "deleted: $name"
}

cmd_projects() {
  hdr "projects"
  echo ""
  if [[ ! -f "$DATA/.projects" ]]; then
    info "no projects — try: init <name>"
    echo ""; return
  fi
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    local badge=""
    [[ "$p" == "$PROJ" ]] && badge=" ${GR}← current${RS}"
    local node_count=0
    if [[ -d "$DATA/$p/nodes" ]]; then
      node_count=$(ls "$DATA/$p/nodes"/*.node 2>/dev/null | wc -l)
    fi
    printf "  ${OR}%-20s${RS}  ${GL}%s nodes%s\n" "$p" "$node_count" "$badge"
  done < "$DATA/.projects"
  echo ""
}

cmd_switch() {
  local name="$1"
  [[ -z "$name" ]] && { err "usage: switch <project>"; return; }
  if [[ -d "$DATA/$name/nodes" ]]; then
    use_proj "$name"
    ok "switched to: ${OR}${PROJ}${RS}"
  else
    err "project '$name' not found — use: init $name"
  fi
}

cmd_rmproj() {
  local name="$1"
  [[ -z "$name" ]] && { err "usage: rmproj <project>"; return; }
  [[ -d "$DATA/$name" ]] || { err "project '$name' not found"; return; }
  echo -ne "  ${OD}delete project '${name}' and all its data? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }
  rm -rf "$DATA/$name"
  grep -v "^${name}$" "$DATA/.projects" > "$DATA/.projects.tmp" 2>/dev/null
  mv "$DATA/.projects.tmp" "$DATA/.projects"
  ok "deleted project: $name"
}

cmd_reset() {
  echo -ne "  ${RE}reset project '$PROJ'? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }
  rm -f "$NODES"/*.node
  > "$CONNS"
  ok "project '$PROJ' reset"
}

cmd_edit() {
  require_init || return
  local name="$1"
  [[ -z "$name" ]] && { err "usage: edit <name>"; return; }
  node_exists "$name" || { err "not found: $name"; return; }

  local type sub lang
  type=$(node_type "$name"); sub=$(node_subtype "$name"); lang=$(node_lang "$name")

  hdr "edit: $name"
  echo -ne "  ${GL}subtype [passthrough/script/text/decision/variable/sleep] (enter=keep '${sub}'): ${RS}"
  read -r ns; [[ -z "$ns" ]] && ns="$sub"

  local nl="-"
  if [[ "$ns" == "script" || "$ns" == "decision" ]]; then
    echo -ne "  ${GL}lang [bash/python3/node/ruby] (enter=keep '${lang}'): ${RS}"
    read -r nl; [[ -z "$nl" ]] && nl="$lang"
  fi

  local existing
  existing=$(node_body "$name")
  [[ -n "$existing" ]] && echo -e "  ${DM}current body:${RS}" && \
    while IFS= read -r l; do echo -e "  ${GY}│${RS}  ${DM}${l}${RS}"; done <<< "$existing"

  echo -e "  ${GL}enter body lines, then type ${OR}END${RS}${GL} (or KEEP to keep existing):${RS}"
  div

  local nb="" keep=0
  while IFS= read -r bl; do
    [[ "$bl" == "END"  ]] && break
    [[ "$bl" == "KEEP" ]] && keep=1 && break
    nb+="${bl}"$'\n'
  done
  [[ $keep -eq 1 ]] && nb="$existing"
  nb="${nb%$'\n'}"

  node_save "$name" "$type" "$ns" "$nl" "$nb"
  ok "saved: $name"
  cmd_show "$name"
}

cmd_export() {
  require_init || return
  local out="${1:-workflow_export.sh}"
  hdr "export → $out"
  local visited_e=()
  {
    echo "#!/usr/bin/env bash"
    echo "# exported by flow.sh"
    echo ""

    exp_node() {
      local id="$1"
      for v in "${visited_e[@]}"; do [[ "$v" == "$id" ]] && return; done
      visited_e+=("$id")
      local t s lg b
      t=$(node_type "$id"); s=$(node_subtype "$id")
      lg=$(node_lang "$id"); b=$(node_body "$id")
      if [[ "$t" == "command" && "$s" == "script" && -n "$b" ]]; then
        echo "# ── $id [$lg] ──"
        # resolve imports so exported script is self-contained
        resolve_imports "$b" "$lg"
        echo ""
      elif [[ "$t" == "command" && "$s" == "variable" && -n "$b" ]]; then
        echo "# ── variable: $id [$lg] ──"; echo "$b"; echo ""
      elif [[ "$t" == "command" && "$s" == "decision" && -n "$b" ]]; then
        echo "# ── decision: $id [$lg] ──"; echo "$b"; echo ""
      elif [[ "$t" == "command" && "$s" == "text" && -n "$b" ]]; then
        echo "# ── $id [text] ──"; echo "\"$b\""; echo ""
      elif [[ "$t" == "command" && "$s" == "sleep" ]]; then
        echo "# ── $id [sleep: ${b}s] ──"
        echo "sleep $b"
        echo ""
      fi
      mapfile -t kids < <(conn_out "$id")
      for k in "${kids[@]}"; do exp_node "$k"; done
    }

    node_exists "start" && exp_node "start"
  } > "$out"
  chmod +x "$out"
  ok "exported: $out"
  info "run with: bash $out"
}

# ═══════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════

cmd_help() {
  hdr "commands"
  echo ""
  local cmds=(
    "init [name]"               "create a new project with start + end nodes"
    "switch <project>"          "switch to an existing project"
    "add <name> [sub] [lang]"   "add a node  (sub: passthrough|text|script|decision|variable|sleep)"
    "setbody <name> <content>"  "set a node's body (inline)"
    "edit <name>"               "edit subtype, lang, and body — supports decision nodes"
    "connect <from> <to> [t|f]" "link nodes — decision nodes require true or false branch"
    "disconnect <from> <to>"    "remove a link"
    "show <name>"               "inspect a node"
    "list"                      "list current project nodes + connections"
    "list --all"                "list all projects and their nodes"
    "sort <node>"               "reorder children of a node interactively"
    "tree"                      "show current workflow as tree"
    "run"                       "execute the current workflow (foreground)"
    "runbg"                     "run workflow fully in background (detached)"
    "delete <name>"             "remove a node"
    "export [file.sh]"          "export to runnable bash script"
    "reset"                     "wipe current project"
    "projects"                  "list all projects"
    "rmproj <project>"          "delete a project and all its data"
    "help"                      "this screen"
    "exit / quit"               "exit"
  )
  local i=0
  while [[ $i -lt ${#cmds[@]} ]]; do
    printf "  ${OR}%-30s${RS}${WD}%s${RS}\n" "${cmds[$i]}" "${cmds[$((i+1))]}"
    i=$((i+2))
  done

  echo ""
  hdr "quick example"
  echo ""
  echo -e "  ${GL}init mybot${RS}"
  echo -e "  ${GL}add fetch script bash${RS}"
  echo -e "  ${GL}setbody fetch echo Hello world${RS}"
  echo -e "  ${GL}add log text${RS}"
  echo -e "  ${GL}setbody log done!${RS}"
  echo -e "  ${GL}add wait sleep 2${RS}"
  echo -e "  ${GL}connect start fetch${RS}"
  echo -e "  ${GL}connect fetch log${RS}"
  echo -e "  ${GL}connect log end${RS}"
  echo -e "  ${GL}run${RS}"
  echo ""
}

cmd_clear() {
  clear
  banner
  info "type ${OR}help${RS}${WD} for commands"
  info "project: ${OR}${PROJ}${RS}  |  data: ${GL}$DATA/$PROJ${RS}"
  echo ""
}
