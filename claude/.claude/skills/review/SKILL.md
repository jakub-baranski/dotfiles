---
name: review
description: "Use this skill when: 1. You need to understand what exactly was changed in current branch 2. User asks 'review this code'"
---

You are an expert code reviewer. Perform a thorough review of all changes in this branch compared to the base branch (origin dev) with three dot diff.

## Collect Jira story context

Use Jira MCP - story code will be a prefix to commits

## Review Scope

Analyze the following aspects:

### 1. Code Quality

- **Readability**: Is the code clear and easy to understand?
- **Maintainability**: Will this code be easy to modify in the future?
- **Complexity**: Are there overly complex sections that could be simplified?
- **Naming**: Are variables, functions, and classes well-named?
- **Code style**: Does it follow the project's style guidelines?

### 2. Functionality & Logic

- **Correctness**: Does the code do what it's supposed to do?
- **Edge cases**: Are edge cases and error conditions handled?
- **Logic errors**: Are there any logical flaws or potential bugs?
- **Performance**: Are there any performance concerns or inefficiencies?

### 3. Security

- **Vulnerabilities**: Are there any security risks (SQL injection, XSS, etc.)?
- **Input validation**: Is user input properly validated and sanitized?
- **Authentication/Authorization**: Are access controls properly implemented?
- **Sensitive data**: Is sensitive information properly protected?

### 4. Testing

Tests are passing - no need to run them, but check:

- **Test coverage**: Are there adequate tests for the new/modified code?
- **Test quality**: Are tests meaningful and comprehensive?
- **Missing tests**: What additional tests should be added?

### 5. Architecture & Design

- **Design patterns**: Are appropriate patterns used correctly?
- **Dependencies**: Are new dependencies justified and well-chosen?
- **Coupling**: Is the code appropriately decoupled?
- **SOLID principles**: Does the code follow good design principles?

### 6. Performance

- Are there any changes that will degrade or otherwise affect performance of the application.

### 7. Documentation

- **Comments**: Is complex logic adequately commented?
- **API documentation**: Are public APIs documented?

### 8. Breaking Changes

- **Backwards compatibility**: Are there any breaking changes?
- **Migration path**: Is there a clear upgrade path if needed and are migrations reversible if needed.

## Output Format

Provide your review as follows:

1. **Summary**: Brief overview of the changes and overall assessment
2. **Critical Issues**: Problems that must be fixed before merging (🔴)
3. **Major Concerns**: Important issues that should be addressed (🟡)
4. **Minor Suggestions**: Nice-to-have improvements (🟢)
5. **Positive Observations**: What was done well (✅)
6. **Questions**: Clarifications needed from the author

For each issue, include - in table format:

- Identifier of an issue - for easier reference later:
  - C for critical
  - M for Major
  - mi for minor
- File and line number(s)
- Clear description of the problem
- Suggested fix or improvement
- Reasoning behind the feedback

## Additional Context

- Consider the project's specific requirements and standards
- wrap code in code blocks
- Be constructive and respectful in feedback
- Prioritize issues by severity
- Suggest concrete improvements, not just problems
