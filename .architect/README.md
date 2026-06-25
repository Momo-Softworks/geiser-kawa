# geiser-kawa modernization — architect handoff

This directory is the plan for modernizing **geiser-kawa** (Momo Softworks fork).
It is written so a *fresh* AI agent — or the NaviGator worker runner — can execute
the work without re-deriving context.

## Files
- **`plan.yaml`** — the DAG of leaf goals. Each goal has a frozen `contract`,
  inlined `context`, and a mechanical `verify`. The top comment block lists the
  **frozen seams** and **file ownership** — read it first.
- **`CURRENT-STATE.md`** — the full current-state map of the repo (elisp modules,
  the Elisp↔Java protocol, build, tests, gaps). The source of truth; cite it.

## Who does what
- **Architect (Opus / a capable model):** owns the seams in `plan.yaml`, repairs
  escalations, and personally handles the *stretch backlog* below. Does NOT write
  feature code.
- **Workers (NaviGator models via `delegate.py`):** execute one leaf goal each,
  graded by its `verify`.

## How to run
From the repo root, **inside a shell that has the toolchain** (JDK 17, Emacs 27+,
Cask, git, and network for Maven/jitpack/MELPA). On Samuel's Guix box, reuse the
existing geiser-kawa env:

```bash
guix shell -L ~/.config/guix/modules -m ~/Projects/kawa/guix.scm -- \
  python3 ~/.claude/skills/architect/scripts/delegate.py \
    .architect/plan.yaml --list                       # status of every goal
```

Then drive it (use the **agentic** executor — goals edit existing files in place):

```bash
... delegate.py .architect/plan.yaml --all  --executor eca   # run all ready goals
... delegate.py .architect/plan.yaml --goal build-kawa311 --executor eca
```

Progress is tracked in `.architect/plan.state.json` (sidecar; `plan.yaml` is never
rewritten). Per-goal transcripts land in `.architect/transcripts/<goal>.md` — relay
those when reporting.

## Suggested order (the DAG resolves this, but for intuition)
1. `elisp-modernize` and `build-kawa311` are the two roots — run them first.
2. **`build-kawa311` is the high-risk node.** It must move off the jitpack
   `kawa-devutil` git-pin onto a clean Kawa 3.1.1 and may need Java edits against
   changed Kawa internals. If a worker burns its budget, it escalates with the
   compiler errors — that's the architect's to repair (freeze a reduced Java seam,
   vendor kawa-devutil, or do that one node by hand). Samuel has Kawa 3.1.1 at
   `~/Projects/KawaCraft/libs/kawa.jar` for `install:install-file` if Central
   lacks it.
3. Everything else depends on one of those two.

## For a FRESH ARCHITECT session (you, handling an escalation)

You are a capable model (Claude) opened in `~/Projects/geiser-kawa` and asked to
act as the architect for `.architect/plan.yaml`. You did NOT write this plan and
you are NOT here to do the whole project — the free NaviGator workers run the
goals; you are called in *only* to repair what they could not pass. Get oriented
fast and spend as few tokens as possible:

1. **Orient (read once):** the FROZEN SEAMS + FILE OWNERSHIP block at the top of
   `plan.yaml`, and `CURRENT-STATE.md`. That is the whole design.
2. **Find the escalation:** `delegate.py .architect/plan.yaml --list` (look for
   `escalate`), or read `.architect/plan.state.json`.
3. **See it fail yourself:** read the worker transcript at
   `.architect/transcripts/<goal>.md`, then run that goal's `verify` command and
   read the real error. Do not trust the worker's summary.
4. **Repair — cheapest fix first:**
   a. *Inline what it guessed wrong.* Most worker failures are a missing literal
      (a class name, a constant, a method signature). Paste it into the goal's
      `context`/`contract` in `plan.yaml`, then re-run just that goal:
      `delegate.py .architect/plan.yaml --goal <id> --executor eca`.
   b. *Split it* into smaller leaves if it bundles >1 concern.
   c. *Do it yourself* if it is genuinely above worker level (expected for
      `build-kawa311`'s Kawa-internals migration). Implement that ONE leaf, run
      its `verify` to green, mark it done in `.architect/plan.state.json`
      (`{"<id>": {"status": "done", "attempts": N}}`), and move on.
5. **Never edit a frozen seam to make a check pass.** S1/S2/S3 names are fixed;
   fix the implementation, not the contract. If a seam is genuinely wrong that is
   a deliberate design change — say so explicitly and reduce it on purpose, then
   update every goal that referenced it.
6. **Resume the workers:** `delegate.py .architect/plan.yaml --all --executor eca`.

Keep your footprint small: repair, resume, stop. You don't need to read the whole
codebase — the seams + CURRENT-STATE.md are the contract.

## Stretch backlog (architect-owned; deliberately NOT worker goals)
These need design judgment or reach into hard Kawa internals — do them yourself
after the v1 DAG is green, each as its own follow-up goal once the seam is known:
- **xref / jump-to-def** — `geiser:symbol-location` returning `(file . line)`;
  Kawa tracks source locations only for some bindings, so this is best-effort.
- **`symbol-documentation`** geiser method (currently in `unsupported-procedures`).
- **macroexpand-1 vs macroexpand-all** — blocked by "can't pass keyword args
  java←kawa" (GeiserMacroexpand.java TODO); needs a protocol tweak on both sides.
- **`enter-debugger`** — currently a stub.
- **Remote `.class` injection** — base64 the kawa-geiser classes over the geiser
  connection so a remote/in-game Kawa REPL gains `geiser:*` without a classpath
  dep (would upgrade `connect-repl` to full completion/autodoc against the live
  game). Author's idea in upstream TODO.org.
- **MELPA recipe** + **auto-download Kawa manual** (sha256-checked) — packaging.

## Fork / publishing
Local git is already set: branch `main`, `origin =
git@github.com:Momo-Softworks/geiser-kawa.git`, `upstream =
https://gitlab.com/emacs-geiser/kawa.git`. Create the GitHub repo, then
`git push -u origin main`. Keep `geiser-kawa`/`geiser:*`/`kawa-geiser` names
unchanged (seam S1/S2) so the fork stays mergeable upstream later.
