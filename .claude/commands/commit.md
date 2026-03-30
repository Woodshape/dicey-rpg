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

Classify every changed file into one of two buckets:

| Bucket | Paths |
|--------|-------|
| **code** | `src/`, `sim/`, `tests/`, `data/`, `assets/`, build files, `CLAUDE.md`, `.claude/` (commands, config) |
| **docs** | `docs/` (everything under it) |

If a file doesn't fit either bucket (e.g. root config files, `.gitignore`), put it in **code**.

## Step 2: Summarize changes per bucket

For each bucket that has changes:

1. Read the diffs (and file contents if needed) to understand what changed and why.
2. For **code** changes — reference `docs/codebase/` and `docs/core-mechanics.md` if you need context on what a module does or what mechanic a change relates to.
3. For **docs** changes — note which doc files were added, updated, or removed and what topic they cover.

## Step 3: Draft commit messages

Follow the project's existing commit style:
- **Lowercase**, terse, no conventional-commits prefix (no `feat:`, `fix:`, etc.)
- Describe what changed in a few words — like a changelog entry, not a paragraph
- For docs-only commits, prefix with `docs/` followed by the topic (e.g. `docs/ condition system`, `docs/ update plans`)
- For code commits, describe the change directly (e.g. `shield absorption blocks damage before HP`, `ai picks highest-value die when tied`)

Draft one message per bucket. If only one bucket has changes, there's only one commit.

## Step 4: Stage and commit

For each bucket (code first, then docs if both exist):

1. `git add` only the files in that bucket — list them explicitly, never use `git add -A` or `git add .`
2. `git commit -m "<message>"` using the drafted message — pass via HEREDOC for clean formatting
3. Run `git status` after to confirm it worked

If only one bucket has changes, make one commit. If both, make two commits in sequence (code first, docs second).

## Step 5: Report

Show the user:
- Each commit hash and message
- Files included in each commit
- Any files that were left uncommitted (and why, if applicable)
