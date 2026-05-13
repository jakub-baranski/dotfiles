---
name: react-testing
description: Write comprehensive *react* unit and integration tests following project conventions and best practices. Use this skill when 1. You need to write tests for React components, hooks, or related logic. 2. User asks "write tests for this component", "add tests for this hook", "improve test coverage", etc.
---

# Testing Skill

## Stack

- **Runner**: Check package.json for `vitest` configuration
- **React**: `@testing-library/react`, `@testing-library/user-event`

## Workflow

1. **Plan first** — List all test cases, get user confirmation before writing
2. **Write iteratively** — One test at a time, run and pass before moving on

## Core Patterns

### User Interactions — Always `userEvent`, NEVER `fireEvent`

```typescript
import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"

it("handles user input", async () => {
  const user = userEvent.setup()
  render(<LoginForm />)

  await user.type(screen.getByLabelText(/email/i), "user@example.com")
  await user.click(screen.getByRole("button", { name: /submit/i }))
})
```

### Async Operations — Use `waitFor`

```typescript
await waitFor(() => {
  expect(screen.getByText("Loading complete")).toBeInTheDocument()
}, { timeout: 3000 })
```


## High ROI Testing (MANDATORY)

**Only write tests that prevent real bugs, not tests that achieve coverage metrics.**

### ✅ HIGH ROI — Always Test

- Complex business logic with multiple branches/edge cases
- Data transformations (parsing, validation, normalization)
- Error handling with multiple states
- Critical user paths (auth, payments, data submission)
- Bug-prone or frequently modified code

### ❌ LOW ROI — Skip

- Simple pass-through functions, trivial getters/setters
- Framework code (React, Zustand, TanStack Query itself)
- Pure I/O without transformation logic
- Obvious behavior (`return a + b`), static config objects

### ROI Evaluation

Ask: **"If this breaks, how would we know?"**
- User reports bug → HIGH ROI
- TypeScript/CI catches it → LOW ROI
- Silent failure → HIGH ROI

**Rule: 10 tests for critical code > 100 tests for trivial code**

### Example Decisions

```typescript
// ❌ LOW ROI — Trivial Zustand store
export const useRegisterStore = create((set) => ({
  password: null,
  setPassword: (password) => set({ password })
}))

// ❌ LOW ROI — Thin I/O wrapper
export async function saveStepData<T>(step: 1|2|3, data: T): Promise<void> {
  await registerStorage.setItem(getStepKey(step), data)
}

// ✅ HIGH ROI — Complex validation with branches
export async function validateStepAccess(requestedStep: number): Promise<StepValidationResult> {
  if (requestedStep === 1) return { canAccess: true, redirectTo: null }
  const step1Complete = await checkStep1()
  if (!step1Complete) return { canAccess: false, redirectTo: 1 }
  // ... more branches
}

// ✅ HIGH ROI — Error transformation
export function normalizeApiError(error: unknown): FriendlyError {
  if (error instanceof NetworkError) return { message: "Connection failed", code: "NETWORK" }
  if (error instanceof ValidationError) return { message: error.details, code: "VALIDATION" }
  return { message: "Unknown error", code: "UNKNOWN" }
}
```

## Unit-Testable Logic in I/O Functions

**Don't skip testing based on function names.** HTTP/database functions often contain pure logic worth testing.

**Unit-testable in I/O functions:**
- Request/response transformations
- Header construction, URL building
- Error normalization, status code routing
- Parse/validation logic

**Requires integration tests:**
- Actual network calls, real database ops, file system I/O

## Test Behavior, Not Implementation

**Ask: "Would a consumer of this API care about this test?"**
- Test breaks on internal refactor → testing implementation ❌
- Test breaks on behavior change → testing behavior ✅

### Assert vs Avoid

| ✅ Assert (Behavior) | ❌ Avoid (Implementation) |
|---------------------|--------------------------|
| Return values | Mock call arguments structure |
| Thrown errors | Internal function calls |
| Observable side effects | `mockFetch.mock.calls[0]` inspection |
| Error messages | `expect(mockFn).toHaveBeenCalledWith(exactArgs)` |

```typescript
// ❌ BAD — Testing implementation
it("calls fetch with correct headers", async () => {
  await httpResource("/api/test")
  expect(mockFetch).toHaveBeenCalledWith(expect.any(URL), expect.objectContaining({
    headers: expect.objectContaining({ "Content-Type": "application/json" })
  }))
})

// ✅ GOOD — Testing behavior
it("returns data when authenticated", async () => {
  mockFetch.mockResolvedValue(new Response(JSON.stringify({ data: "test" }), { status: 200 }))
  const result = await httpResource("/api/test")
  expect(result).toEqual({ data: "test" })
})
```

**Keep internal functions private. Test the public contract.**

## Data-Driven Testing with `it.each`

**Use object-based test cases for readability:**

```typescript
const testCases = [
  { description: "value within range", value: 5, min: 0, max: 10, expected: 5 },
  { description: "value below min", value: -5, min: 0, max: 10, expected: 0 },
  { description: "value above max", value: 15, min: 0, max: 10, expected: 10 },
]

it.each(testCases)("returns correct value when $description", ({ value, min, max, expected }) => {
  expect(clamp(value, min, max)).toBe(expected)
})
```

**Benefits:** Self-documenting, no positional confusion, `$description` interpolation


## Quality Checklist

- [ ] `userEvent` for all interactions, no manual `act()` around it
- [ ] `waitFor` for async operations
- [ ] Object-based `it.each` test cases
- [ ] Tests behavior, not implementation
- [ ] Reasonable test count — no redundant assertions
- [ ] All tests pass with zero warnings

## Common Issues

```typescript
// Multiple buttons — use specific identifiers
screen.getByRole("button", { name: /browse files/i })  // ✅
screen.getByRole("button")  // ❌ fails with multiple buttons

// State updates — use act() for DOM events, but NOT with userEvent
act(() => { component.dispatchEvent(dragEnterEvent) })  // ✅ DOM events
await user.click(button)  // ✅ userEvent handles act() internally
```

## Running Tests

```bash
pnpm test                          # Run all
pnpm test path/to/file.spec.tsx    # Run specific file
vitest                             # Watch mode
vitest --coverage                  # With coverage
```

