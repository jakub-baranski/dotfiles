---
name: refactoring
description: "Use this skill when: 1. Code is hard to understand or maintain. 2. Functions/classes are too large. 3. Code smells need addressing. 4. Adding features is difficult due to code structure. 5. User asks 'clean up this code', 'refactor this', 'improve this' "
---

# The Golden Rules
- Behavior is preserved - Refactoring doesn't change what the code does, only how.
- Small steps - Make tiny changes, test after each.
- Version control is your friend - Commit before and after each safe state.
- Tests are essential - Without tests, you're not refactoring, you're editing.
- One thing at a time - Don't mix refactoring with feature changes.

# When NOT to Refactor
- Code that works and won't change again (if it ain't broke...).
- Critical production code without tests (add tests first).
- When you're under a tight deadline.
- "Just because" - need a clear purpose.

# Refactoring Checklist

## Code Quality
 - Functions are preferably small (< 50 lines).
 - Functions do one thing.
 - No duplicated code.
 - Descriptive names (variables, functions, classes).
 - No magic numbers/strings.
 - Dead code removed.

## Structure
 - Related code is together.
 - Clear module boundaries.
 - Dependencies flow in one direction.
 - No circular dependencies.

## Type Safety
 - Types defined for all public APIs.
 - No 'any' types without justification.
 - Nullable types explicitly marked.
 
## Testing
 - Refactored code is tested.
 - Tests cover edge cases.
 - All tests pass.
 - All static checks (type checks, lint) pass.
