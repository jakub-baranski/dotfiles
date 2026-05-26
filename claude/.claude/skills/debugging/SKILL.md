---
name: debugging
description: Guide for debugging general errors. Use this when asked to fix a general issue.
---

# Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

Core principle: ALWAYS find root cause before attempting fixes.
Symptom fixes are failure.

Violating the letter of this process is violating the spirit of debugging.

## The Iron Law

NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
If you haven't completed Phase 1, you cannot propose fixes.

## General user interaction guidelines

1. Always check with the user using `askUserQuestion` if the issue is
resolved and if not - ask for more details and continue fixing until the issue
is resolved.
2. Always provide user with a free form answer for your question
when asking if problem has been resolved or if they can provide more details.

## Phase 1: Root Cause Investigation

BEFORE attempting ANY fix:

### Read Error Messages Carefully

Don't skip past errors or warnings
They often contain the exact solution
Read stack traces completely
Note line numbers, file paths, error codes

### Reproduce Consistently

Can you trigger it reliably?
What are the exact steps?
Does it happen every time?
If not reproducible → gather more data, don't guess

### Check Recent Changes

What changed that could cause this?
Git diff, recent commits
New dependencies, config changes
Environmental differences

## Phase 2: Pattern Analysis

Find the pattern before fixing:

1. Find Working Examples

- Locate similar working code in same codebase
- What works that's similar to what's broken?
- Compare Against References

1. If implementing pattern, read reference implementation COMPLETELY

- Don't skim - read every line
- Understand the pattern fully before applying
- Identify Differences

1. What's different between working and broken?

- List every difference, however small
- Don't assume "that can't matter"

1. Understand Dependencies

- What other components does this need?
- What settings, config, environment?
- What assumptions does it make?

## Phase 3: Hypothesis and Testing

Scientific method:

1. Form Single Hypothesis

- State clearly: "I think X is the root cause because Y"
- Write it down
- Be specific, not vague

1. Test Minimally

- Make the SMALLEST possible change to test hypothesis
- One variable at a time
- Don't fix multiple things at once

1. Verify Before Continuing

- Did it work? Yes → Phase 4
- Didn't work? Form NEW hypothesis
- DON'T add more fixes on top

1. When You Don't Know

- Say "I don't understand X"
- Don't pretend to know
- Ask for help
- Research more

## Phase 4: Implementation

Fix the root cause, not the symptom:

1. Create Failing Test Case

- Simplest possible reproduction
- Automated test if possible
- One-off test script if no framework
- MUST have before fixing
- Use the superpowers:test-driven-development skill for writing proper failing tests

1. Implement Single Fix

- Address the root cause identified
- ONE change at a time
- No "while I'm here" improvements
- No bundled refactoring

1. Verify Fix

- Test passes now?
- No other tests broken?
- Issue actually resolved?

1. If Fix Doesn't Work

- STOP
- Count: How many fixes have you tried?
- If < 3: Return to Phase 1, re-analyze with new information
- If ≥ 3: STOP and question the architecture (step 5 below)
- DON'T attempt Fix #4 without architectural discussion
- If 3+ Fixes Failed: Question Architecture

### Pattern indicating architectural problem

- Each fix reveals new shared state/coupling/problem in different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

### STOP and question fundamentals

- Is this pattern fundamentally sound?
- Are we "sticking with it through sheer inertia"?
- Should we refactor architecture vs. continue fixing symptoms?
- Discuss with your human partner before attempting more fixes

This is NOT a failed hypothesis - this is a wrong architecture.

## Red Flags - STOP and Follow Process

If you catch yourself thinking:

"Quick fix for now, investigate later"
"Just try changing X and see if it works"
"Add multiple changes, run tests"
"Skip the test, I'll manually verify"
"It's probably X, let me fix that"
"I don't fully understand but this might work"
"Pattern says X but I'll adapt it differently"
"Here are the main problems: [lists fixes without investigation]"
Proposing solutions before tracing data flow
"One more fix attempt" (when already tried 2+)
Each fix reveals new problem in different place

*ALL of these mean: STOP. Return to Phase 1.
