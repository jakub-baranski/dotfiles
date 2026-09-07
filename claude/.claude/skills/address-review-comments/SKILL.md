---
name: address-review-comments
description: "Use this skill when asked to address, apply, or fix review comments, or when the user mentions their local review comments / .review-comments.json"
---

# Address local review comments

The user writes review comments in Neovim (diffview) with a personal plugin. They are stored in `.review-comments.json` at the git repository root. Your job: read them, act on each unresolved comment, and mark it resolved.

## File format

```json
{ "version": 1, "comments": [
  {"id":"a1b2c3","path":"src/foo.lua","side":"b","start_line":12,"end_line":15,
   "resolved":false,"created_at":"...","updated_at":"...",
   "text":"the comment (may be multi-line)","snapshot":["exact line text","..."]}
] }
```

- `path` — relative to the repo root.
- `side` — `"b"`: the comment targets the current/new version of the file. `"a"`: it was written on the **old** side of a diff (removed/changed lines); the referenced code may no longer exist in the working tree — the `snapshot` shows what it looked like.
- `start_line`/`end_line` — 1-based inclusive, valid at the time of writing; the file may have drifted since. **Trust `snapshot` over line numbers**: search for the snapshot text to find where the comment applies now.
- `snapshot` — the exact lines the comment was written on.

## Workflow

1. Read `.review-comments.json` at the repo root.
2. For each comment with `"resolved": false`, in file order:
   - Locate the referenced code (snapshot first, line numbers as a hint).
   - Do what the comment asks. Comments may be requests ("extract this"), questions, or observations — answer questions in your reply instead of editing code.
   - If you disagree with a comment or it no longer applies, do NOT silently skip it: say so in your summary and leave it unresolved unless the user tells you otherwise.
3. After successfully addressing a comment, update its entry in `.review-comments.json`: set `"resolved": true` and set `"updated_at"` to the current UTC time (`YYYY-MM-DDTHH:MM:SSZ`). Leave `id`, line numbers, and `snapshot` untouched.
4. Preserve the file's formatting exactly: header line `{ "version": 1, "comments": [`, one comment object per line (keys in the order shown above), closing `] }`. Edit lines in place; do not reserialize the whole file.
5. In your summary, list each comment id/path with what you did, plus any you left unresolved and why. Remind the user to run `:ReviewComment refresh` in Neovim to reload the file.
