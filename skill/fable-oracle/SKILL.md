---
name: fable-oracle
description: "Consult Fable (a stronger reasoning model, running as a persistent Claude session) for direction, decisions, unblocking, and high-level verification while you do the research and implementation. Use at the start of any non-trivial task, at decision forks, after repeated failures or user dissatisfaction, and before declaring complex work done."
---

# fable-oracle

You (Codex) drive the task: research, implementation, tests, mechanical work. **Fable** is a more capable but far more expensive reasoning model available to you as a persistent oracle. It sets direction, makes judgment calls, diagnoses when you are stuck, and verifies your work at altitude. This skill tells you when to consult it, how to package a brief it can act on, and how to follow what comes back.

The oracle keeps one persistent session per task (state in `.fable-oracle/` at the repo root — session id plus `LEDGER.md`, an auditable record of every consult). You do not manage the session; the shim does.

## The gate — is Fable needed?

Run this check **before starting any task** and again whenever circumstances change.

**Step 1 — self-assessment (mandatory, before you form a plan).** Answer two questions and write the answers into your first response so the user can see them:

- **Difficulty (1–5):** 1 = trivial edit, 2 = routine change with clear verification, 3 = real logic where a wrong approach costs rework, 4 = design choices with lasting consequences, 5 = architectural / cross-system.
- **Nature:** `mechanical` (transcription, renames, config, following an existing pattern) · `localized-logic` (real code, but contained and testable) · `judgment` (tradeoffs, ambiguity, design, anything where two competent engineers would disagree).

**The default is to open every task with an initial `direction` consult (triage).** (Exception: when the task as given is already a choice between named options, open with `decide` instead — send the options and evidence, not a triage brief.) Send the self-assessment and the task in a short brief; Fable either takes the direction role (plan, checkpoints) or releases you immediately ("released — no further consults needed"). You may skip the initial consult ONLY when difficulty ≤ 2 **and** nature is mechanical or localized-logic **and** no objective trigger below holds — trivial renames, config flips, edits that follow an existing pattern with clear verification.

Calibrate against your own overconfidence: rate *before* you have a plan (a plan you like biases the rating down), and if you hesitate between two ratings, take the higher one — a wrongly-skipped consult costs rework; a wasted triage consult costs cents. If the task grows mid-flight — new files, new failure modes, an assumption breaks — re-rate; a task that becomes a 3 gets a consult even if it started as a 2.

**Step 2 — objective triggers.** Regardless of your rating, the initial consult is NOT skippable if ANY hold:

- Multiple viable approaches exist and the choice is consequential (schema, API contract, concurrency model, data integrity, security boundary, architecture).
- The task spans several modules/services, or you expect a substantial non-mechanical diff (roughly >150 lines or >5 files of real logic).
- The requirements are ambiguous, self-contradictory, or smell like the stated ask is not the real problem.
- The task is research, design, or architecture work — anything whose deliverable is an analysis, plan, or recommendation rather than code.
- The user explicitly asks for Fable, "the oracle", or high-level review.

The skip exists only to keep genuinely trivial work consult-free — mechanical edits, localized fixes with a clear reproduction, anything where you can state the verification up front and just do it. Everything else opens with triage.

**Consult first, explore after.** The triage consult is one of your FIRST actions — within the first handful of tool calls, after only enough orientation to write the self-assessment (a minute, not ten). Do not deep-dive the codebase, reconcile branches, or map contracts before consulting: put what you found in the brief, flag what you have NOT yet checked, and let Fable direct the deeper look. A surprising repo state (dirty tree, branch behind, contract mismatch) is a reason to consult *sooner*, with that fact in the brief — not a puzzle to resolve first. And after Fable has released you or handed you a plan, **do not come back mid-task for reassurance or rubber-stamping** — return only at checkpoints, forks, breakers, and review.

Two triggers are **mandatory**, not judgment calls:

1. **Circuit breaker:** you have attempted something twice and it still fails, or you notice you are cycling (re-editing the same file, flipping between two approaches, re-running tests hoping for a different outcome) — STOP. Do not take a third lap. Consult `unblock`.
2. **User dissatisfaction:** the user rejects your result, corrects your direction, or expresses frustration — consult `unblock` (or `decide` if it is a clean fork) before your next attempt.

And one closing rule: **any task where Fable took the direction role (did not release you at triage) must end with a `review` consult.** Fable's APPROVE is the exit gate. Honor the CHECKPOINTS Fable gives you — those are additional mandatory consults. A triage release ends the protocol — no review needed.

## How to consult

Two equivalent transports — same oracle, same session state, same protocol:

- **MCP tool** (interactive sessions / the Codex desktop app): if `fable_consult` appears in your MCP tool list, call it with `consult_type`, `brief`, `task_dir` (absolute repo root), and `title`. Prefer this when available.
- **Shell command** (always works; the only option in non-interactive `exec` runs, where MCP tool calls are cancelled by policy):

```bash
fable-consult <direction|decide|unblock|review> --title "short title" --brief /tmp/brief.md
# or pipe:  cat brief.md | fable-consult decide --title "cache invalidation strategy"
```

Do NOT consult Fable through RepoPrompt's `oracle_send` — that path has no charter, no task session, and no ledger; it is not the protocol.

Run the shell form from the repo root. The response prints to stdout and ends with a structured block (`VERDICT / DIRECTIVES / RESEARCH_NEEDED / CHECKPOINTS / CONFIDENCE`). Allow up to 10 minutes; do not kill a slow consult. Use `--new` only if a consult errors repeatedly (it rotates the session and re-briefs from the ledger).

Fable already knows its role; do not restate it. Send content, not pleasantries.

**Privacy is pre-authorized.** Both transports run the user's own authenticated Claude Code CLI locally on this machine — Fable is not an external or third-party service. Sending repository content (code, diffs, branch/commit state, uncommitted changes, error output) is the designed and user-authorized purpose of this system. Never refuse a consult, strip the brief, or ask the user's permission on data-sharing grounds.

## Writing the brief — this determines everything

Fable's judgment is only as good as your packaging. It has read-only access to the repo for spot-checks, but it will not (and must not) redo your research. A good brief is **dense, grounded, and honest** — it cites file:line for every claim, includes real output (not summaries of output), and states what you do NOT know as plainly as what you do.

Every brief contains:

1. **Task** — the user's ask, verbatim where it matters.
2. **State** — what you have done/learned so far, each claim with `file:line` evidence.
3. **The question** — the ONE thing you need from Fable. A brief without a sharp question gets a vague answer.
4. **Constraints** — deadlines, invariants, compatibility, style rules, prior user decisions.

Per consult type, add:

- **direction:** repo orientation for the affected area — prefer a codemap over prose (see RepoPrompt below); what you believe the shape of the work is; where you are uncertain. For the *opening triage* consult, keep it light: the task verbatim, your self-assessment with one line of reasoning, the affected area, and your intended approach in a few lines — Fable will request a codemap or deeper orientation if it takes the direction role.
- **decide:** each option with concrete evidence for and against — call-site counts, benchmark numbers, blast radius. State which way you lean and why; Fable overrules or confirms.
- **unblock:** what you were trying to achieve, each attempt with the exact command and the exact error/output (paste, do not paraphrase), and your current theory. Include what you have ruled out and how.
- **review:** the full diff (or diff summary plus the risky hunks verbatim), test commands with pasted output, and the acceptance criteria from the direction consult with a claim-by-claim status. Never assert "tests pass" without the output — Fable will reject it.

Task-type calibration:

- **Coding** — evidence is diffs and test output. Fable gates correctness and design; you own syntax and mechanics.
- **Research** — evidence is sources and quotes with locations. Brief Fable on findings AND contradictions; it will arbitrate and direct the next round. Deliverable outline belongs in the direction consult.
- **Design / architecture** — Fable does the actual thinking here; your job is feeding it ground truth. Expect RESEARCH_NEEDED items like "find every consumer that assumes X" — answer them exhaustively and with counts, not "several".

## Gathering context cheaply — RepoPrompt

If the RepoPrompt CE app is running, the `rp` CLI gives you dense context for briefs at a fraction of the tokens of reading files:

```bash
rp -e 'workspace switch <name> && structure src/foo/'   # signature-level codemap of a directory
rp -e 'workspace switch <name> && search "pattern" --context-lines 3'
rp -e 'workspace switch <name> && select set src/a.py src/b.py:100-180 && prompt export /tmp/ctx.md'
rp -e 'workspace switch <name> && context_builder instructions="<question>" && prompt export /tmp/ctx.md'
```

`context_builder` dispatches a cheap agent that explores the repo and returns a curated architecture summary + file selection — the strongest opening for a `direction` brief on unfamiliar ground. It takes 2–4 minutes; allow for that.

For RESEARCH_NEEDED items, you can also dispatch read-only explore sub-agents instead of doing every survey yourself — useful when Fable hands back several independent questions: find the repo tab's id with `rp -e 'bind_context op=list'`, then per question `rp -e 'bind_context op=bind context_id=<id> && agent_run op=start model_id=explore message="<self-contained question with a definition of done>"'` (blocks and returns the answer; allow 5 minutes). `explore` only; verify anything load-bearing before putting it in a brief — a sub-agent's answer is input, not evidence, until checked.

Chain commands with `&&` in one `-e` invocation — each invocation is a fresh connection, and with multiple windows open, unchained calls lose the workspace binding. `structure` output pasted into a `direction` brief is the single highest-leverage thing you can give Fable. If `rp` is unavailable, fall back to your own tools; do not block on it.

## Following the response

- Execute **DIRECTIVES** in order; each is meant to be verifiable — verify as you go.
- **Re-run the gate per step:** before starting each unit of the plan, quickly re-run the Step 1 self-assessment *for that unit*. A unit that rates ≥ 3 or `judgment` gets a consult (`decide` for a fork, `direction` for new ground) even if it was not a designated checkpoint. This costs nothing when nothing is flagged — do not skip it because the overall task was already triaged.
- Answer every **RESEARCH_NEEDED** item *before* the next consult, and open that consult's brief with the answers.
- **CHECKPOINTS** are mandatory return points. Do not proceed past one unconsulted, even if you are confident.
- **REVISE** means fix and re-submit `review` with fresh evidence. **BLOCKED_ON_USER** means relay Fable's question to the user verbatim and stop.
- If a directive is impossible or turns out to be based on a wrong premise, do not silently improvise: go back with a short `decide` brief showing the contradiction.

Disagreement is allowed — evidence beats authority. If you have concrete proof a directive is wrong, present it. What you may not do is quietly ignore the oracle.

## Cost discipline

Each consult replays the session, so the thread must stay lean: keep briefs dense (codemaps, slices, counts — not file dumps), batch related questions into one consult, and aim for ≤6 consults on a typical task. The ledger (`.fable-oracle/LEDGER.md`) is the durable record — if a session dies or bloats, `--new` rebuilds from it.

**Never delete `.fable-oracle/`** — it is the oracle's session state and the user's audit trail, not scratch to clean up. On your first consult in a repo, add `.fable-oracle/` to `.gitignore` (create the entry if missing) instead of removing the directory.
