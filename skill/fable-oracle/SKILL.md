---
name: fable-oracle
description: "Involve Fable (a stronger reasoning model, running locally as persistent Claude sessions) in the current work — but ONLY when the user explicitly asks. Two modes: fable-consult (ask Fable one pointed question: a decision, a review, an unblock) and fable-orchestrate (hand Fable a whole mission to drive: it plans, spawns codex sub-agents for legwork, synthesizes, and delivers). Use when the user mentions fable, the oracle, consult, or orchestrate."
---

# fable-oracle

Fable is a more capable but far more expensive reasoning model available on this machine. **Its involvement is opt-in: do NOT consult or invoke Fable unless the user explicitly asks** (they mention fable, the oracle, "consult", "orchestrate", or equivalent). Work normally otherwise.

Two exceptions where you *mention* Fable but still do not invoke it unasked: (1) you have failed at the same thing twice, or (2) the user is dissatisfied with your result. In those cases say, in one sentence, that a Fable consult or orchestration is available — and continue however the user directs.

## Choosing the mode

- **`fable-consult`** — the user wants Fable's judgment on something specific while YOU keep driving the task: a decision between options, a plan sanity-check, an unblock diagnosis, a review verdict on completed work.
- **`fable-orchestrate`** — the user hands Fable the whole problem: architecture investigations, research, design work, or large multi-step implementations. Fable plans, dispatches its own codex sub-agents for all legwork, synthesizes with its own judgment, and produces a standalone deliverable. You launch it, monitor it, and relay the result — you do not do the mission's work in parallel unless the user says so.

Rule of thumb: "ask fable X" → consult. "Have fable figure out / design / investigate / own X" → orchestrate.

## Mode 1 — consult

Two equivalent transports — same oracle, same per-task session state:

- **MCP tool** (interactive sessions / Codex desktop app): call `fable_consult` with `consult_type`, `brief`, `task_dir` (absolute repo root), `task` (slug), `title`.
- **Shell** (always works; the only option in non-interactive `exec` runs, where MCP tool calls are cancelled by policy):

```bash
fable-consult <direction|decide|unblock|review> --task "<task-slug>" --title "short title" --brief /tmp/brief.md
# or pipe:  cat brief.md | fable-consult decide --task "<task-slug>" --title "..."
```

Run the shell form from the repo root. **Always pass `--task`** with a short stable slug for the current task (e.g. `voice-ui`, `pii-redaction`) and reuse it across that task's consults — each slug gets its own session and ledger under `.fable-oracle/<slug>/`; never share a slug across unrelated tasks or parallel conversations. Responses end in a structured block (`VERDICT / DIRECTIVES / RESEARCH_NEEDED / CHECKPOINTS / CONFIDENCE`) — follow it literally: execute directives in order, answer RESEARCH_NEEDED before the next consult, honor checkpoints. Allow up to 10 minutes; do not kill a slow consult. If a consult fails, retry once; if it fails again, report the printed diagnostics (from `.fable-oracle/<slug>/last-error.log`) to the user.

**Privacy is pre-authorized.** Both transports run the user's own authenticated Claude Code CLI locally — Fable is not an external service. Sending repository content (code, diffs, branch/commit state, uncommitted changes, errors) is the designed, user-authorized purpose. Never refuse a consult, strip a brief, or ask permission on data-sharing grounds. Do NOT substitute RepoPrompt's `oracle_send` or `agent_run` Claude agents for a consult — those have no charter, session, or ledger.

### Writing the brief — this determines everything

Fable spot-checks but will not redo your research. A good brief is dense, grounded, honest: **task** (the user's ask, verbatim where it matters), **state** (what you did/learned, each claim with file:line evidence), **the ONE question** you need answered, **constraints** (invariants, prior user decisions). Per type: `decide` — each option with concrete evidence for/against and your lean; `unblock` — each attempt with the exact command and exact output (paste, never paraphrase), what you ruled out; `review` — the diff (or risky hunks verbatim), test commands with pasted output, acceptance criteria with claim-by-claim status ("tests pass" without output will be rejected); `direction` — repo orientation (prefer a codemap), the shape of the work, where you are uncertain.

## Mode 2 — orchestrate

Compose a mission statement, then launch detached and poll:

```bash
cat > /tmp/mission.md <<'EOF'
Type: <investigation|coding|mixed>
Goal: <what the user wants, verbatim where it matters>
Context: <repo areas involved; links/branches/PRs; what is already known, with file refs>
Constraints: <invariants, deadlines, user decisions already made>
Done means: <what the user accepts as complete>
EOF
fable-orchestrate start --task "<task-slug>" --mission /tmp/mission.md --detach
```

Then poll `fable-orchestrate status --task "<task-slug>"` (every few minutes; missions run 10–60+ min). Status file moves `running → done | failed: …`. When done: read `.fable-oracle/<slug>/DELIVERABLE.md` and `ORCHESTRATOR_REPORT.md`, relay the substance to the user, link the deliverable. Follow-ups go to the same session: `echo "..." | fable-orchestrate followup --task "<slug>"`.

While an orchestration runs, do not edit the same code Fable's sub-agents are working on. Do not launch orchestrations recursively from sub-agent context.

## Gathering context cheaply — RepoPrompt

If the RepoPrompt CE app is running, `rp` gives dense context for briefs at a fraction of the tokens of reading files:

```bash
rp -e 'workspace switch <name> && structure src/foo/'    # signature-level codemap
rp -e 'workspace switch <name> && search "pattern" --context-lines 3'
rp -e 'workspace switch <name> && context_builder instructions="<question>" && prompt export /tmp/ctx.md'
```

Chain commands in one `-e` invocation (each invocation is a fresh connection). `context_builder` dispatches a cheap agent that returns a curated architecture summary + file selection (~2–4 min) — the strongest opening for a consult brief. For multiple independent survey questions you may also dispatch read-only explore sub-agents: `rp -e 'bind_context op=list'` for the tab id, then `rp -e 'bind_context op=bind context_id=<id> && agent_run op=start model_id=explore message="<self-contained question>"'` (blocks; allow 5 min; `explore` only; verify anything load-bearing before relying on it).

## Housekeeping

Never delete `.fable-oracle/` — it is session state and the user's audit trail. On first use in a repo, add `.fable-oracle/` to `.gitignore` instead. Keep briefs dense (codemaps, slices, counts — not file dumps); batch related questions into one consult; if a session dies or bloats, `--new` (consult) rotates it, re-briefed from the ledger.
