---
name: commit
description: Create a git commit using this project's Conventional Commits style. Use when the user asks to commit changes.
---

# Commit

Create a git commit following this project's conventions.

## Workflow

1. Run in parallel: `git status`, `git diff` (staged + unstaged), and `git log --oneline -10`.
2. Stage the relevant files by name (avoid `git add -A` / `git add .`). Never stage secrets (`Secrets.xcconfig`, `.env`, credentials).
3. Draft the message (see format below), then commit with a HEREDOC.
4. Run `git status` afterward to confirm success.

## Message format

```
type(scope): subject
```

- **type** — use the official Conventional Commits types, whichever fits the change:
  `feat`, `fix`, `build`, `chore`, `ci`, `docs`, `style`, `perf`, `refactor`, `test`, `revert`.
- **scope** — short, lowercase, kebab-case feature area (e.g. `dashboard`, `metric-detail`, `empty-state`, `ui`, `ai`, `translation`). Never uppercase. Omit the parentheses entirely if no scope fits.
- **subject** — concise, imperative mood, no trailing period.

## Body (optional)

- Only add a body when the change isn't self-explanatory from the subject.
- Use `-` bullets. Never write prose paragraphs.
- Wrap lines at ~72 columns.
- Explain *what* changed and *why*, not the mechanics line-by-line.

## Rules

- NEVER add a `Co-Authored-By: Codex` trailer or any Codex attribution.
- Create a new commit; do not amend unless explicitly asked.
- Do not skip hooks (`--no-verify`). If a hook fails, fix the cause and commit again.

## Example

```
feat(dashboard): unify add-metric entry point across dashboard states

- Hoist MetricInputSheet into ContentView so both empty and populated
  dashboards share one sheet and add-metric callback
- Add a primary-action toolbar "+" button and rename title to "My Metrics"
- Render EmptyDashboardBackground behind both states, dimmed when data exists
```
