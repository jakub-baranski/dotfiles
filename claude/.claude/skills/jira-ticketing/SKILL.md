---
name: jira-ticketing
description: "Use this skill when asked to create a jira ticket"
---

# Jira Story Ticket

## Description format

Exactly two blocks, in this order, nothing else:

```
_As a <role>, I want <capability>, so that <benefit>._
 
h3. Acceptance criteria
* <criterion>
* <criterion>
* <criterion>
```

- The user story is **italic** (`_text_` in wiki markup; `"marks": [{"type": "em"}]` in ADF).
- Acceptance criteria are a flat bullet list. Each item is one verifiable statement.
- No other sections unless the user explicitly asks for them.

## Rules

**Write acceptance criteria that are:**

- Verifiable — a tester can mark each one pass/fail without asking questions.
- Specific — name the actual endpoint, field, state, error, limit, or screen.
- Independent — one behavior per bullet.
- Behavior-focused — what the system does, not how it is coded.
**Never put into the description:**
- Narration about the work ("we will need to", "this task involves", "the developer should").
- Implementation plans, file names, class names, step-by-step coding instructions.
- Background essays, motivation paragraphs, restating the story in prose.
- Filler like "as discussed", "TBD", "etc.", "and so on".
- Estimates, assignees, deadlines — those are Jira fields, not description text.
**Summary field:** short imperative phrase, no ticket-type prefix. `Add CSV export to reports list`, not `[Feature] We should add the ability to export`.

## Missing information

If the role, capability, or a testable outcome is unclear, ask before creating the ticket. Do not invent acceptance criteria to fill the shape.

## Example

Summary: `Filter orders list by status`

Description:

```
_As a support agent, I want to filter the orders list by status, so that I can find orders needing action without scrolling._
 
h3. Acceptance criteria
* Status filter is a multi-select with values: New, Paid, Shipped, Cancelled, Refunded.
* Selecting one or more statuses returns only orders in those statuses.
* Selected statuses persist in the URL query string and survive a page reload.
* Clearing the filter returns the unfiltered list.
* Empty result set shows the "No orders match these filters" state.
* Filter applies before pagination; the result count reflects the filtered set.
```
