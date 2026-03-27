# Shutdown — Dicey RPG

> End the session cleanly: sync docs with code, capture new issues and ideas, update plans.

## Instructions

Execute the following steps in order. Do not skip any step.

### Step 1: Identify what changed this session

Review the conversation to identify:
- Which source files (`src/*.odin`) were modified
- Which design decisions were made or changed
- Which bugs or problems were discovered
- Which ideas or design spaces were discussed

### Step 2: Sync design docs with code

For each source file that was modified, read the corresponding `docs/design/*.md` and check:
- Does the design doc still accurately describe the module's architecture, procedures, and contracts?
- Were new procedures added that change how the module is used or extended?
- Were invariants, data structures, or patterns changed?

If a change is significant (new architecture, changed contracts, new patterns), update the design doc. Do NOT update for bugfixes, small tweaks, or implementation details.

The design docs are the **single source of truth**. The code reflects the docs, not the other way around. If the code diverged from a design doc during this session, either the doc should be updated to match the new design decision, or the code should be flagged as divergent.

### Step 3: Update issues

Read `docs/issues/` and:
- **Add** any new issues discovered during this session (concrete problems with negative consequences)
- **Remove** any issues that were resolved during this session
- **Update** any issues where understanding changed

Issues are like GitHub issues — they describe problems and get deleted when fixed.

### Step 3b: Sync TODOs

Grep `src/` for `TODO` comments and cross-check against `docs/todo/`:
- **Add** any in-code TODOs not yet captured in `docs/todo/` (group by category/feature into the appropriate file)
- **Remove** any entries in `docs/todo/` whose corresponding in-code TODO was resolved this session
- **Update** entries where the scope or understanding changed

The rule: every `// TODO` in `src/` must have a corresponding entry in `docs/todo/`, and every entry in `docs/todo/` must have a live `// TODO` in `src/`. Keep them in sync.

### Step 4: Update ideas

Read `docs/ideas/` and:
- **Add** any new design ideas or alternatives discussed during this session
- **Update** existing ideas if the discussion refined or changed them
- Organize into the existing topic files, or create a new file if the topic doesn't fit

Ideas are an ever-growing collection. Do not remove ideas unless they were explicitly rejected.

### Step 5: Update implementation plan

Read `docs/implementation-plan.md` and:
- Check off any tasks completed during this session
- Update milestone status if a milestone was completed
- Note any new tasks that were added to the current milestone

### Step 6: Verify CLAUDE.md

Check whether `CLAUDE.md` needs changes:
- New files or folders not yet documented in the project structure?
- New conventions or workflow rules established during this session?
- Removed or renamed files still listed?

If yes: update `CLAUDE.md`.

### Step 7: Summary

Deliver a brief report:

1. **Done** — what was accomplished this session
2. **Docs updated** — which docs were synced, issues added/resolved, ideas captured
3. **Open** — anything that couldn't be resolved or needs the user's input
4. **Next** — what should be tackled in the next session based on the implementation plan and open issues
