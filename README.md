# fable-oracle

**Codex drives; Fable directs.** A consult protocol for pairing a cheap, fast coding agent (OpenAI Codex) with an expensive, stronger reasoning model (Claude's Fable/Opus tier) — so the cheap model does the research, implementation, and testing, and the expensive model is consulted only for judgment: direction, decisions, unblocking, and verification.

The economics: the task driver burns the vast majority of tokens (every file read, test run, and retry lands in its context). Putting the cheap model in the driver's seat and buying judgment à la carte inverts the cost curve without giving up the quality gate.

## The two modes

**Fable involvement is opt-in** — codex works normally until you explicitly ask for Fable (after two failures or visible dissatisfaction it will *offer* Fable in one sentence, never invoke it unasked).

**`fable-consult`** — codex keeps driving; Fable answers one pointed question. Four consult types (`direction`, `decide`, `unblock`, `review`), a persistent session per task slug, dense evidence-grounded briefs, and structured verdicts (`VERDICT / DIRECTIVES / RESEARCH_NEEDED / CHECKPOINTS`) that codex follows literally. Every consult lands in `.fable-oracle/<task>/LEDGER.md`. Fable stays read-only here: it thinks, codex does.

**`fable-orchestrate`** — the inversion: Fable drives. For architecture investigations, research, design work, and large implementations, Fable becomes the orchestrator — it decomposes the mission, spawns codex sub-agents (cheap, tightly-scoped, each with a validation gate) for all legwork, synthesizes with its own judgment, pressure-tests its recommendation adversarially, and writes a standalone `DELIVERABLE.md` plus an auditable ledger and reference memos. For coding missions its sub-agents write every line; Fable specifies, reviews, and verifies. Runs detached (missions take 10–60+ min):

```bash
fable-orchestrate start --task my-investigation --mission mission.md --detach
fable-orchestrate status --task my-investigation     # running -> done | failed
echo "follow-up question" | fable-orchestrate followup --task my-investigation
```

Rule of thumb: *"ask fable X"* → consult. *"Have fable figure out / design / investigate / own X"* → orchestrate.

## Requirements

- macOS, [Claude Code](https://claude.com/claude-code) CLI (`claude`) authenticated — Fable runs through it
- [Codex](https://developers.openai.com/codex) CLI and/or the Codex desktop app
- Optional but recommended: [RepoPrompt CE](https://github.com/repoprompt/repoprompt-ce) — dense context retrieval (codemaps, curated selections) and cheap explore sub-agents for both sides

## Install

```bash
git clone https://github.com/<you>/fable-oracle.git
cd fable-oracle && ./install.sh
```

The installer is idempotent. It:

- symlinks `fable-consult` (and `rp` for RepoPrompt, if installed) onto your PATH
- installs the `fable-oracle` skill into `~/.codex/skills` (and any `~/.kodex` profiles)
- appends the gate nudge to each `AGENTS.md` so codex reliably opens the skill
- registers the `fable_consult` MCP tool in each `config.toml` (used by interactive codex / the desktop app)
- adds the `[sandbox_workspace_write]` carve-outs (network + `~/.claude`) that consults need to run inside codex's sandbox
- enables RepoPrompt's MCP tools on launch (they default off)

Per repo, add `.fable-oracle/` to `.gitignore`.

## Usage

```bash
cd your-repo
codex                      # interactive: just give it the goal
codex exec -s workspace-write "your goal"   # non-interactive
```

The gate runs automatically. Optional steering: *"consult fable first"* forces a consult; *"no fable on this one"* suppresses it.

**Consult Fable yourself** (joins the same per-task session codex used):

```bash
echo "Why did you approve this? What did you actually check?" | fable-consult decide --title "human check-in"
cat .fable-oracle/LEDGER.md          # full audit trail
```

Env knobs: `FABLE_MODEL` (default `claude-fable-5`), `FABLE_MAX_TURNS` (default 25), `FABLE_ORACLE_DIR` (state dir override).

## What's in the box

```
bin/fable-consult              # consult shim: per-task sessions + ledger (claude -p --resume)
bin/fable-orchestrate          # orchestrator shim: detached missions, status, followups
bin/fable-orchestrate-finish   # post-processor for orchestration output
bin/fable-consult-mcp          # MCP stdio server: fable_consult + fable_orchestrate tools
prompts/oracle-charter.md        # consult-Fable's role: decisive, read-only, evidence-demanding
prompts/orchestrator-charter.md  # orchestrator-Fable's role: decompose, dispatch codex, synthesize, verify
skill/fable-oracle/            # codex-side skill: opt-in rules, mode choice, brief templates
install.sh
```

### Delegation ladder (keeping Fable's tokens on reasoning)

With RepoPrompt installed, both sides delegate legwork to cheap executors:

- `rp -e 'structure <dir>'` — signature-level codemaps, a fraction of the tokens of reading files
- `rp -e 'context_builder instructions="..."'` — a cheap agent explores the repo and returns a curated map + file selection (~2–4 min)
- `agent_run` explore sub-agents — answer one sharp analytical question; used adversarially by Fable before granting APPROVE
- `RESEARCH_NEEDED` — Fable hands surveys back to codex between consults

## Troubleshooting

- **Consult fails with "Not logged in"** — codex's sandbox is blocking the `claude` subprocess. The installer's `[sandbox_workspace_write]` block fixes this; if your config already had that table, merge `network_access = true` and `writable_roots = ["~/.claude"]` manually.
- **MCP tool calls return "user cancelled"** in `codex exec` — codex cancels *all* MCP tool calls in non-interactive runs (verified against other servers too). Not a bug in this package; the skill routes exec runs through the shell command instead.
- **RepoPrompt tools missing / only 3 tools** — per-window MCP tools default off; the installer sets `mcp.autoStart`. Restart the app.
- **`rp` bindings lost between commands** — each `rp -e` invocation is a fresh connection; chain with `&&` in one `-e` string.
- **Session bloat / dead session** — `fable-consult <type> --new` rotates to a fresh session re-briefed from the ledger tail.

## License

MIT
