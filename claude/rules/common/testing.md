# Testing Requirements

## Risk-Scaled Testing (default)

Tests exist to prove behavior, not to satisfy a ritual. Scale them to the change:

1. **Bug fix** → add a regression test that reproduces the original defect alongside the fix.
2. **Behavior change** → test at the level closest to the behavior's contract (unit for pure logic, integration for API/DB boundaries).
3. **Critical user paths** → add integration/E2E coverage proportional to risk.
4. **Coverage** → follow the project's own configured threshold / CI gate. If the project defines none, do not invent a global number.
5. **Full suite** → run it when the blast radius warrants it, or in Critical mode; otherwise run targeted tests + the directly related suite and **state explicitly what was not run**.

Never delete, skip, or weaken tests to make them pass (Safety Rules). Test conclusions require real execution output as evidence.

## Test-Driven Development (Critical mode & high-risk changes)

For Critical-mode tasks and risk-bearing new features, prefer the TDD loop:

1. Write test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)

TDD here is the preferred discipline for that risk class — not a global mandate for every edit.

## Troubleshooting Test Failures

1. Check test isolation
2. Verify mocks are correct
3. Fix implementation, not tests (unless tests are wrong)

## Test Structure (AAA Pattern)

Prefer Arrange-Act-Assert structure for tests:

```typescript
test('calculates similarity correctly', () => {
  // Arrange
  const vector1 = [1, 0, 0]
  const vector2 = [0, 1, 0]

  // Act
  const similarity = calculateCosineSimilarity(vector1, vector2)

  // Assert
  expect(similarity).toBe(0)
})
```

### Test Naming

Use descriptive names that explain the behavior under test:

```typescript
test('returns empty array when no markets match query', () => {})
test('throws error when API key is missing', () => {})
test('falls back to substring search when Redis is unavailable', () => {})
```
