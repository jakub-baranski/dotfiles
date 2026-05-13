---
name: redux-tests
description: "Use this skill when: 1. You need to write tests for a React app using Redux."
---

## Prefer writing integration tests with everything working together. 

- For a React app using Redux, render a <Provider> with a real store instance wrapping the components being tested. Interactions with the page being tested should use real Redux logic, with API calls mocked out so app code doesn't have to change, and assert that the UI is updated appropriately.
- If needed, use basic unit tests for pure functions such as particularly complex reducers or selectors. However, in many cases, these are just implementation details that are covered by integration tests instead.
- Do not try to mock selector functions or the React-Redux hooks! Mocking imports from libraries is fragile, and doesn't give you confidence that your actual app code is working.
