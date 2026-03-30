# Commit — Dicey RPG

> Stage and commit changes, keeping code and docs in separate commits.

## Rules

- **Never mix code and docs in the same commit.** If both `src/`, `sim/`, `tests/`, `data/`, `assets/` AND `docs/` have changes, create two separate commits.
- **Never append a Co-Authored-By line** or any AI attribution trailer to the commit message.
- **Never override the git author.** Use the system default — do not pass `--author` or set `GIT_AUTHOR_*` / `GIT_COMMITTER_*`.
- **Never push.** Only commit locally.

## Step 1: Inspect the working tree

Run in parallel:
- `git status` — identify changed, staged, and untracked files
- `git diff` — see unstaged changes
- `git diff --cached` — see already-staged changes

Classify every changed file into one of three buckets:

| Bucket | Paths |
|--------|-------|
| **code** | `src/`, `sim/`, `tests/`, `assets/`, build files, `CLAUDE.md`, `.claude/` (commands, config) |
| **data** | `data/` (character configs, encounter definitions) |
| **docs** | `docs/` (everything under it) |

If a file doesn't fit any bucket (e.g. root config files, `.gitignore`), put it in **code**.

## Step 2: Summarize changes per bucket

For each bucket that has changes:

1. Read the diffs (and file contents if needed) to understand what changed and why.
2. For **code** changes — reference `docs/codebase/` and `docs/core-mechanics.md` if you need context on what a module does or what mechanic a change relates to.
3. For **data** changes — note which character or encounter configs changed and what balance parameters were tuned.
4. For **docs** changes — note which doc files were added, updated, or removed and what topic they cover.

## Step 3: Draft commit messages

Each commit message has two parts: a **subject line** and a **body**.

### Subject line

Follow the project's existing commit style:
- **Lowercase**, terse, no conventional-commits prefix (no `feat:`, `fix:`, etc.)
- Describe what changed in a few words — like a changelog entry, not a paragraph
- For docs-only commits, prefix with `docs/` followed by the topic (e.g. `docs/ condition system`, `docs/ update plans`)
- For data-only commits, prefix with `data/` followed by what changed (e.g. `data/ buff goblin HP and attack`, `data/ add forest encounter`)
- For code commits, describe the change directly (e.g. `shield absorption blocks damage before HP`, `ai picks highest-value die when tied`)

### Body (detailed description)

After a blank line, add a body that makes the commit grep-able and useful as a searchable changelog. Include:

- **What changed:** which modules/systems were touched and what was added, removed, or modified
- **Why:** the motivation — what problem this solves, what mechanic it implements, or what bug it fixes
- **Key details:** specific procedures, structs, or constants that were added/changed — enough that `git log --grep="shield"` or `git log --grep="ai scoring"` finds the right commit
- **Files touched:** list the changed files (one per line, prefixed with `-`)

Keep it factual and concise — a few lines, not an essay. Example:

```
shield absorption blocks damage before HP

Shield condition now absorbs incoming damage before it reaches character HP.
Absorption reduces shield stacks first; excess damage passes through.

- What: add absorb_damage to condition.odin, wire into resolve_attack in combat.odin
- Why: shields were decorative — they applied but never blocked anything
- Files:
  - src/condition.odin
  - src/combat.odin
  - tests/condition_test.odin
```

Draft one message per bucket. If only one bucket has changes, there's only one commit. If multiple buckets have changes, commit in order: code → data → docs.

## Step 4: Stage and commit

For each bucket (code first, then docs if both exist):

1. `git add` only the files in that bucket — list them explicitly, never use `git add -A` or `git add .`
2. `git commit` using the drafted message — pass subject + body via HEREDOC to preserve the multi-line format:
   ```bash
   git commit -m "$(cat <<'EOF'
   subject line here

   Body paragraph here.

   - What: ...
   - Why: ...
   - Files:
     - src/foo.odin
   EOF
   )"
   ```
3. Run `git status` after to confirm it worked

If only one bucket has changes, make one commit. If multiple buckets have changes, make separate commits in sequence (code → data → docs).

## Step 5: Report

Show the user:
- Each commit hash and message
- Files included in each commit
- Any files that were left uncommitted (and why, if applicable)
