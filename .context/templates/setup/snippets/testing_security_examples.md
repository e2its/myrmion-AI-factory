---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial snippet version"
---

# Test Examples (TDD + Security)

## TDD Cycle (Python)
```python
# 1. RED: Write test first
def test_create_user_with_valid_email():
    """User creation should succeed with valid email."""
    user = User.create(email="test@example.com", password="SecureP@ss123")
    assert user.email == "test@example.com"
    assert user.is_active is True

# 2. Run test → FAILS (User.create doesn't exist yet)

# 3. GREEN: Implement minimal code
class User:
    def __init__(self, email: str, password: str):
        self.email = email
        self.password = password
        self.is_active = True

    @classmethod
    def create(cls, email: str, password: str) -> "User":
        return cls(email, password)

# 4. Run test → PASSES

# 5. REFACTOR: Add validation
class User:
    def __init__(self, email: str, password: str):
        if not self._is_valid_email(email):
            raise ValueError("Invalid email format")
        self.email = email
        self.password = password
        self.is_active = True

    @staticmethod
    def _is_valid_email(email: str) -> bool:
        return "@" in email  # Simplified

    @classmethod
    def create(cls, email: str, password: str) -> "User":
        return cls(email, password)
```

## OWASP Security Tests

### SQL Injection
```python
def test_user_search_prevents_sql_injection():
    """User search should escape SQL special characters."""
    malicious_input = "'; DROP TABLE users;--"
    result = user_service.search(malicious_input)
    assert result == []
```

### XSS
```typescript
test('comment submission sanitizes HTML', async () => {
  const xssPayload = '<script>alert("XSS")</script>';
  const comment = await commentService.create(xssPayload);
  expect(comment.content).toBe('&lt;script&gt;alert("XSS")&lt;/script&gt;');
});
```

### CSRF
```python
def test_state_changing_endpoint_requires_csrf_token():
    """POST/PUT/DELETE endpoints must validate CSRF token."""
    response = client.post("/api/users/delete", headers={})
    assert response.status_code == 403
```

### AuthN/AuthZ
```typescript
test('protected endpoint rejects unauthenticated requests', async () => {
  const response = await request(app).get('/api/admin/users');
  expect(response.status).toBe(401);
});

test('admin endpoint rejects non-admin users', async () => {
  const userToken = await getTokenForRole('user');
  const response = await request(app)
    .get('/api/admin/users')
    .set('Authorization', `Bearer ${userToken}`);
  expect(response.status).toBe(403);
});
```
