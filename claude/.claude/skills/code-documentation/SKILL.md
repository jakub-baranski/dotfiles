---
name: code-documentation
description: Guide for commenting code. Use this when asked to add, correct or refactor comments.
---

# Overview

Random verbose comments are bloating files and are overloading the reader.

Core principle: Comment only when necessary to understand code.
Don't comment what is done, comment why it's done this way.

## Comments — hard rules

- A comment must make sense to a reader who has never seen the prior version of the file.
  If it only makes sense in contrast to what the code *used to* do, delete it.
- Forbidden phrasings — if you find yourself writing any of these, delete the comment:
  - "no longer needed", "previously we", "instead of X"
  - "not X — X is for Y" (comparison to a sibling/removed path)
  - "added for", "regression for", "fix for", "per ticket/PR ..."
  - "on initial sync ...", "after the X parser runs ..."
  (cross-file ordering — read the call site)
- Don't restate what a type annotation, `NotRequired`, `total=False`, `Optional`,
or a clear name already encodes.
- Test docstrings: same rules. Test names describe behavior;
Docstrings only exist for a non-obvious invariant. Never narrate the bug history.
- One sentence max per comment unless documenting a specific external spec/bug ID.
- Don't put comments explaining what the code does.
- Comment only non-obvious things and add a comment explaining "why"
something is done this way.
- Keep comments short, understandable and glanceable.
- Avoid docstring reiterating name of the method or class.
