# Snapshot Skill

Write or update `progress.md` in the project root to capture current state, learnings, and next steps.

## Instructions

When this skill is invoked, do the following — do not ask clarifying questions, just execute.

### 1. Gather current state

Run these in parallel:
- `git status --short` — untracked and modified files
- `git diff --stat HEAD` — summary of staged/unstaged changes vs last commit
- `git log --oneline -10` — recent commit history for context
- `git stash list` — any stashed work

Also read `progress.md` if it already exists, so you can update rather than replace it.

### 2. Synthesise

Write (or rewrite) `progress.md` in the project root with these sections:

**Current Status** — one short paragraph describing where things stand right now.

**Completed Work** — bullet list of things that are done and working, with enough detail that a future agent won't re-do them. Include:
- What was changed and why
- Any files that were updated in-place vs new files added
- Which build/test targets have been verified

**Cleanup Needed** — flag anything that is messy, redundant, or dangerous and should be addressed before moving on (e.g. dead files, wrong logic, half-finished state). Be specific: name the files and explain why.

**Immediate Next Steps** — an ordered list of the next concrete actions. Each item should be specific enough that a future agent can pick it up cold without asking questions. Include any gotchas or ordering constraints.

**Longer-term Backlog** — lower-priority items, wishlist features, and known future work. Can be brief.

**Key Notes** — anything a future agent must know to avoid mistakes: non-obvious architecture decisions, dangerous files, known landmines.

### 3. Write the file

Write the completed `progress.md` to the project root. If one already exists, replace it entirely — do not append. The file should stand alone as a complete snapshot, not accumulate history.

Do not create any other files. Do not commit anything. Just write `progress.md` and confirm it is done.
