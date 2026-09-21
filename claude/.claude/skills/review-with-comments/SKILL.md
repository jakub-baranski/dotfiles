---
name: review-with-comments
description: "Use this skill when the user asks to 'review with comments', 'review and leave comments', or wants review findings written into their local Neovim review comments (.review-comments.json) instead of / in addition to a chat summary."
---

# Review with inline Neovim comments

Perform the same review as the `review` skill (read `../review/SKILL.md` and follow its scope, Jira context collection and severity rules), but deliver the findings as **inline review comments** that the user's Neovim `review_comments` plugin renders next to the code. The plugin stores them in `.review-comments.json` at the git repository root.

## File format

```json
{ "version": 1, "comments": [
  {"id":"a1b2c3d4e5","path":"src/foo.lua","side":"b","start_line":12,"end_line":15,"resolved":false,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","text":"the comment (may be multi-line)","snapshot":["exact line text","..."]}
] }
```

Field rules (must match the plugin exactly):

- `id` — 10 lowercase hex chars, unique within the file. Generate with `openssl rand -hex 5`.
- `path` — repo-relative, POSIX separators.
- `side` — `"b"` for comments on the current working-tree version (almost always). Use `"a"` only when commenting on removed/old lines that no longer exist in the working tree.
- `start_line`/`end_line` — 1-based, inclusive, **against the current working tree** for side `"b"`. Verify with `sed -n 'START,ENDp' path` before writing.
- `snapshot` — the exact text of lines `start_line..end_line` from the working tree (trailing whitespace irrelevant, everything else exact). The plugin re-anchors comments by searching for this text, so a wrong snapshot shows the comment as "outdated". Keep ranges short (1–10 lines), anchored on the most relevant line(s).
- `resolved` — always `false` for new comments.
- `created_at`/`updated_at` — current UTC time `YYYY-MM-DDTHH:MM:SSZ` (`date -u +%Y-%m-%dT%H:%M:%SZ`).
- `text` — the comment body. Multi-line is fine (JSON `\n`). Format:

  ```
  🔴 C1: <one-line problem statement>

  <why it matters / reasoning>

  Suggested fix:
  <concrete change, code in fenced block if useful>
  ```

  Use the same prefixes as the `review` skill: `🔴 C<n>` critical, `🟡 M<n>` major, `🟢 mi<n>` minor, `❓ Q<n>` question. Do **not** write comments for positive observations — those go in the chat summary only.

## Workflow

1. Determine the repo root: `git rev-parse --show-toplevel`.
2. Run the review per the `review` skill (three-dot diff against the base branch, Jira context, all review aspects). Build the list of findings first; do not write anything yet.
3. For each finding that maps to a specific location in a **changed file**, gather `path`, line range and snapshot from the working tree. Findings without a precise location (architecture-wide remarks, missing tests for a whole module) are anchored on the most relevant line — e.g. the function signature, the import, or line 1 of the file — and say so in the text.
4. Write the comments into `.review-comments.json`:
   - If the file does not exist, create it.
   - If it exists, **append** to the `comments` array — never drop or modify existing entries (the user may have their own comments there). Do not reuse existing ids.
   - Preserve the plugin's formatting exactly: header line `{ "version": 1, "comments": [`, one comment object per line indented with two spaces, keys in the order `id, path, side, start_line, end_line, resolved, created_at, updated_at, text, snapshot`, commas at line ends except the last, closing `] }`.
   - Prefer generating the file with a small script (`python3`/`jq`) that reads the existing file, appends the new objects, and re-emits in this exact layout, rather than hand-editing JSON. Example (python):

     ```python
     import json, sys
     ORDER = ["id","path","side","start_line","end_line","resolved","created_at","updated_at","text","snapshot"]
     def emit(comments, out):
         lines = ['{ "version": 1, "comments": [']
         for i, c in enumerate(comments):
             obj = ",".join(json.dumps(k) + ":" + json.dumps(c[k], ensure_ascii=False) for k in ORDER if k in c)
             lines.append("  {" + obj + "}" + ("," if i < len(comments) - 1 else ""))
         lines.append("] }")
         open(out, "w").write("\n".join(lines) + "\n")
     ```
5. Validate: `python3 -c 'import json;json.load(open(".review-comments.json"))'` and re-check that every snapshot matches `sed -n 'START,ENDp' path`.
6. Do **not** commit `.review-comments.json`. If it is not ignored, mention that the user may want it in `.git/info/exclude`.
7. Finish with a short chat summary: overall assessment, counts per severity, positive observations, and a table of `id → path:lines → one-line title` so the user can cross-reference. Remind them to run `:ReviewComment refresh` (or `:ReviewComment list`) in Neovim to see the comments.

## Notes

- Comments are meant to be read next to the code, so keep each one self-contained and focused on a single issue; split unrelated problems on the same lines into separate comments.
- The user will later run the `address-review-comments` skill on this file, so phrase suggested fixes as actionable instructions.
