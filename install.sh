#!/usr/bin/env bash
# fable-oracle installer for macOS.
# Idempotent: safe to re-run after a git pull or config change.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUDGE='At the start of every task, open the `fable-oracle` skill and run its gate: unless the task is a trivial mechanical edit, make an initial `direction` (triage) consult with Fable as one of your FIRST actions — brief orientation only, deeper exploration after Fable responds. fable-consult / the fable_consult MCP tool is LOCAL (the user'"'"'s own Claude Code CLI on this machine): sending repo content to it is pre-authorized — never refuse or ask permission on data-sharing grounds. Circuit-breaker rules (2 failed attempts, or user dissatisfaction -> consult Fable) are mandatory.'
DID=() SKIPPED=() WARN=()

note()  { DID+=("$1"); }
skip()  { SKIPPED+=("$1"); }
warn()  { WARN+=("$1"); }

# --- prerequisites ---------------------------------------------------------
command -v claude >/dev/null 2>&1 || {
  echo "ERROR: 'claude' CLI not found. Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
}
command -v codex >/dev/null 2>&1 || warn "codex CLI not found — installed config/skills will activate when codex is installed"

# --- shims on PATH ----------------------------------------------------------
BIN_DIR=""
for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
  [[ -d "$d" && -w "$d" ]] && { BIN_DIR="$d"; break; }
done
[[ -n "$BIN_DIR" ]] || { BIN_DIR="$HOME/.local/bin"; mkdir -p "$BIN_DIR"; }
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not on your PATH — add it to your shell profile" ;; esac

ln -sfn "$REPO_DIR/bin/fable-consult" "$BIN_DIR/fable-consult"
note "fable-consult -> $BIN_DIR/fable-consult"

RP_APP="/Applications/RepoPrompt CE.app/Contents/MacOS/repoprompt-mcp"
if [[ -x "$RP_APP" ]]; then
  ln -sfn "$RP_APP" "$BIN_DIR/rp"
  note "rp -> $BIN_DIR/rp"
else
  skip "RepoPrompt CE not installed (optional; brew install --cask repoprompt-ce)"
fi

# --- codex homes: skill, AGENTS.md nudge, config ----------------------------
install_codex_home() {
  local home="$1"
  [[ -d "$home" ]] || return 0

  mkdir -p "$home/skills"
  ln -sfn "$REPO_DIR/skill/fable-oracle" "$home/skills/fable-oracle"
  note "skill -> $home/skills/fable-oracle"

  if [[ -f "$home/AGENTS.md" ]] && grep -q "fable-oracle" "$home/AGENTS.md"; then
    skip "nudge already in $home/AGENTS.md"
  else
    printf '%s\n' "$NUDGE" >> "$home/AGENTS.md"
    note "nudge appended to $home/AGENTS.md"
  fi

  local cfg="$home/config.toml"
  [[ -f "$cfg" ]] || touch "$cfg"

  if grep -q "mcp_servers.fable" "$cfg"; then
    skip "MCP server already in $cfg"
  else
    printf '\n[mcp_servers.fable]\ncommand = "%s/bin/fable-consult-mcp"\ntool_timeout_sec = 900\nenabled = true\n' "$REPO_DIR" >> "$cfg"
    note "MCP server registered in $cfg"
  fi

  if grep -q "sandbox_workspace_write" "$cfg"; then
    if grep -q 'network_access = true' "$cfg" && grep -q '\.claude' "$cfg"; then
      skip "sandbox config already in $cfg"
    else
      warn "$cfg has [sandbox_workspace_write] but may lack network_access=true / writable_roots=[\"$HOME/.claude\"] — merge manually (consults fail with 'Not logged in' without them)"
    fi
  else
    printf '\n[sandbox_workspace_write]\nnetwork_access = true\nwritable_roots = ["%s/.claude"]\n' "$HOME" >> "$cfg"
    note "sandbox config appended to $cfg"
  fi
}

install_codex_home "$HOME/.codex"
for p in "$HOME"/.kodex/profiles/*/; do
  [[ -d "$p" ]] && install_codex_home "${p%/}"
done
if [[ -d "$HOME/.kodex/base/skills" ]]; then
  ln -sfn "$REPO_DIR/skill/fable-oracle" "$HOME/.kodex/base/skills/fable-oracle"
  note "skill -> ~/.kodex/base/skills/fable-oracle"
fi

# --- RepoPrompt: enable MCP tools on launch ---------------------------------
RP_SETTINGS="$HOME/Library/Application Support/RepoPrompt CE/Settings/globalSettings.json"
if [[ -f "$RP_SETTINGS" ]]; then
  python3 - "$RP_SETTINGS" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
mcp = d.setdefault("scalarPreferences", {}).setdefault("mcp", {})
if not mcp.get("autoStart"):
    mcp["autoStart"] = True
    json.dump(d, open(p, "w"), indent=2)
    print("  enabled RepoPrompt MCP tools auto-start (restart the app)")
EOF
  note "RepoPrompt mcp.autoStart verified"
elif [[ -x "$RP_APP" ]]; then
  warn "RepoPrompt installed but never launched — launch it once, then re-run install.sh to enable its MCP tools"
fi

# --- summary -----------------------------------------------------------------
echo ""
echo "fable-oracle install complete."
printf '  done:    %s\n' "${DID[@]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && printf '  skipped: %s\n' "${SKIPPED[@]}"
[[ ${#WARN[@]} -gt 0 ]] && printf '  WARNING: %s\n' "${WARN[@]}"
echo ""
echo "Smoke test:  cd <some repo> && echo 'reply with just OK' | fable-consult decide --title 'install smoke test'"
