# ${project_name} — Product Owner package

Package **${package_id}**. It lets you shape the next evolution of the product in a Claude Desktop project, and hand the result back in a form the engineering side can take in without rewriting it.

## How to use it

1. Create a project in Claude Desktop.
2. Paste the content of **`PROJECT-INSTRUCTIONS.md`** into the project instructions. Copy it from the `.md` file, exactly.
3. Upload **`00-core/`**, **`10-design-system/`** and **`30-templates/`** to the project knowledge.
4. Do **not** upload `20-features/`. Those are the heavy annexes. Attach to the chat only the folder of the feature you are working on.
5. Check the project understood: ask it *"which features are specified and which are only on the roadmap?"*. It should tell ${n_specified} from ${n_roadmap}. If it cannot, the knowledge did not index; upload it again.

To work on the **design system** instead of a feature, create a second project with **`PROJECT-INSTRUCTIONS-VISION.md`** (present only when this package covers the design system) and the same knowledge.

## What is inside

| Folder | Upload to knowledge | What it is |
|---|---|---|
| `00-core/` | Yes | The product in one page, the feature catalogue, the glossary, the route map, the roadmap, the rules of the game |
| `10-design-system/` | Yes | Style guide, component library, tokens, the component base and one card per component |
| `20-features/` | **No** — attach per chat | The current documents of each specified feature |
| `30-templates/` | Yes | The moulds for everything you hand back |

## The four files that matter most

- `00-core/domain-glossary.md` — the closed vocabulary. Look here before naming anything.
- `00-core/rules-of-the-game.md` — what you may propose and what each kind of change costs.
- `10-design-system/components.md` — what already exists to compose screens with.
- `30-templates/ERQ-TEMPLATE.md` — how to say what you change and why.

## What is expected back

```
MANIFEST.yaml          <- index of everything you bring
FEAT-XXX/
  ERQ.md               <- what you change and why
  user_journey.md      <- the journey and the business contract, complete
  spec.feature         <- the behaviour scenarios
  mock.html            <- the navigable screen, when there is one
VISION/                <- only for a design-system return
```

Send small returns often: two or three features are reviewed and taken in within a day; twelve take weeks, and by then the product has moved underneath them.

The documents you return are read with the **same** automatic checks the engineering side applies to its own. A clean report means your return can be reviewed. It does not mean it is accepted: each change is then decided one by one, and you get a written account of what went in and what did not.
