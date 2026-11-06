---
description: "Monetary amounts — one value object: integer minor units plus an ISO 4217 currency, no floats, same-currency arithmetic, explicit rounding. Lands only when SETUP Q36 answered that the product handles money (EVOL-072)."
applicable_when:
  phase: [BLUEPRINT, IMPLEMENT]
---

# Monetary Amounts

> Lands because `docs/setup.md` → `domain.monetary_amounts: true` (Q36). Domain guidance, not a law: no gate and no defect class.
> On the wire, an amount is the same pair: `{ "amount": 2999, "currency": "EUR" }` (minor units, ISO 4217). An amount that can pass 2^53 travels as a decimal string (`"2999"`) — a JSON number above it loses precision in JavaScript; a `bigint` amount always does. One project, one wire type: pick it once in the contract. Bound it at the edge: a string amount `pattern: '^-?[0-9]{1,18}$'`, a currency `pattern: '^[A-Z]{3}$'` checked against ISO 4217.

## The value object

- **Shape:** an integer in **minor units** (cents for EUR, none for JPY) plus an **ISO 4217** currency code. The currency's exponent comes from ISO 4217, never from a guess.
- **No floats, ever.** A float in an amount, a price or a rate applied to an amount is a defect. A rate is a decimal or a ratio of integers.
- **Arithmetic stays within one currency.** Adding or comparing two currencies is an error, not a conversion. A conversion is its own operation and names its rate and its source.
- **Rounding is explicit.** Every operation that can produce a fraction of a minor unit (a percentage, a split, a conversion) names its rounding mode, for example half-even. A split allocates the remainder; it never loses a cent.
- **One type end to end.** The database column, the domain object and the contract carry the same pair. Formatting for display happens at the edge, by locale.

## Snippets

Each snippet shows the shape, the integer guard, the same-currency guard and overflow as an error — arithmetic never wraps. A runtime without a snippet follows the same contract.

**Python**
```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Money:
    minor: int        # integer minor units
    currency: str     # ISO 4217, e.g. "EUR"

    def __post_init__(self):
        if type(self.minor) is not int:   # a float or a bool is no amount
            raise TypeError(f"minor units are an int, not {type(self.minor).__name__}")

    def __add__(self, other: "Money") -> "Money":
        if other.currency != self.currency:
            raise ValueError(f"cannot add {other.currency} to {self.currency}")
        return Money(self.minor + other.minor, self.currency)
```

**TypeScript**
```typescript
export interface Money { readonly minor: bigint; readonly currency: string } // ISO 4217
// JSON.stringify throws on a bigint: serialise `minor` as a decimal string, never through Number.
export const toJson = (m: Money) => ({ amount: m.minor.toString(), currency: m.currency });

export function add(a: Money, b: Money): Money {
  if (a.currency !== b.currency) throw new Error(`cannot add ${b.currency} to ${a.currency}`);
  return { minor: a.minor + b.minor, currency: a.currency };
}
```

**Java**
```java
public record Money(long minor, java.util.Currency currency) {
    public Money add(Money other) {
        if (!currency.equals(other.currency)) throw new IllegalArgumentException("cannot add " + other.currency + " to " + currency);
        return new Money(Math.addExact(minor, other.minor), currency);
    }
}
```

**Go**
```go
type Money struct {
	Minor    int64  // integer minor units
	Currency string // ISO 4217
}

func (m Money) Add(o Money) (Money, error) {
	if o.Currency != m.Currency {
		return Money{}, fmt.Errorf("cannot add %s to %s", o.Currency, m.Currency)
	}
	if (o.Minor > 0 && m.Minor > math.MaxInt64-o.Minor) || (o.Minor < 0 && m.Minor < math.MinInt64-o.Minor) {
		return Money{}, errors.New("overflow") // int64 wraps silently: check before adding
	}
	return Money{m.Minor + o.Minor, m.Currency}, nil
}
```

**C#**
```csharp
public readonly record struct Money(long Minor, string Currency) // ISO 4217
{
    public Money Add(Money other) =>
        other.Currency == Currency ? this with { Minor = checked(Minor + other.Minor) }
        : throw new InvalidOperationException($"cannot add {other.Currency} to {Currency}");
}
```

**Rust**
```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Money { pub minor: i64, pub currency: [u8; 3] } // ISO 4217

impl Money {
    pub fn add(self, other: Money) -> Result<Money, String> {
        if self.currency != other.currency { return Err("cannot add two currencies".into()); }
        self.minor.checked_add(other.minor).map(|minor| Money { minor, ..self }).ok_or("overflow".into())
    }
}
```
