---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial snippet version"
---

# DDD and ACL Patterns (Snippets)

## Repositories (Python)
```python
# domain/repositories/user_repository.py
class IUserRepository(ABC):
    @abstractmethod
    async def find_by_id(self, user_id: str) -> User | None: ...
    
    @abstractmethod
    async def save(self, user: User) -> None: ...

# infra/persistence/user_repository_impl.py
class UserRepositoryImpl(IUserRepository):
    def __init__(self, session: AsyncSession):
        self._session = session
    
    async def find_by_id(self, user_id: str) -> User | None:
        # SQLAlchemy implementation
        ...
```

## Domain Events (TypeScript)
```typescript
// domain/events/user_registered.ts
export class UserRegisteredEvent {
  constructor(
    public readonly userId: string,
    public readonly email: string,
    public readonly occurredAt: Date
  ) {}
}

// application/use_cases/register_user.ts
async registerUser(dto: RegisterUserDTO): Promise<User> {
  const user = User.create(dto.email, dto.password);
  await this.userRepo.save(user);
  await this.eventBus.publish(new UserRegisteredEvent(user.id, user.email, new Date()));
  return user;
}
```

## CQRS (Schema)
- **Command:** `CreateUserCommand` → writes to normalized RDBMS.
- **Query:** `GetUserProfileQuery` → reads from denormalized model (e.g., ElasticSearch).

## Anti-Corruption Layer (Adapter, Python)
```python
# domain/services/payment_gateway.py (interface)
class IPaymentGateway(ABC):
    @abstractmethod
    async def charge(self, amount: Money, token: str) -> PaymentResult: ...

# infra/payment/stripe_adapter.py
class StripeAdapter(IPaymentGateway):
    def __init__(self, stripe_client: stripe.Client):
        self._stripe = stripe_client
    
    async def charge(self, amount: Money, token: str) -> PaymentResult:
        stripe_amount = int(amount.value * 100)
        charge = await self._stripe.charges.create(
            amount=stripe_amount,
            currency=amount.currency.lower(),
            source=token
        )
        return PaymentResult(success=charge.status == "succeeded", transaction_id=charge.id)
```
