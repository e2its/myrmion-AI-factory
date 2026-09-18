# Rules of the game

## What you can do

- Propose changes to any feature, specified or on the roadmap.
- Add a step, a state, a message, an optional field, a business rule.
- Propose a new concept or a new component, saying what you looked up first.
- Recommend an order of priority.
- Leave a question open when you do not know.

## What you cannot do

- Redesign a screen that works because a different one would be nicer.
- Invent a name for something the glossary already names.
- Ask for a new component when one in `../10-design-system/components.md` solves the case.
- Write technical types, formats, storage or protocol names.
- Decide when something is built, or bring a roadmap feature forward.
- Change the global navigation as a side effect of one feature. It is shared by every feature; it is a design-system change.
- Relax a rule the product states as unbreakable.

## What each kind of change really costs

| Change | Cost | Why |
|---|---|---|
| Text, order, empty state, error message | Very low | Touches the screen only |
| New optional field on an existing concept | Low | Added without breaking what works |
| New step in an existing journey | Medium | Screen, scenarios and tests |
| New **required** field | High | Someone must decide what happens to what already exists without it |
| New concept or new action | High | Contract, storage, tests, the whole journey |
| Changing what something existing means | Very high | Breaks what is built and what is already stored |
| Global navigation | Very high | Affects every feature at once |
| Anything on a roadmap feature | **Almost none** | Nothing is built yet |

## How what goes in is decided

1. Your return is checked for form. A return that fails goes back to you with the report, unedited.
2. Each change is weighed and decided one by one. Nothing is applied automatically.
3. What is accepted is taken in as you wrote it. What is not is told to you with the reason.
4. When it is built is decided on the project board.
