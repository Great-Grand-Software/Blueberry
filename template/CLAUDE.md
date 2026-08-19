# <YOUR GAME>

Godot 4 / GDScript 2D game, shipped as a single-threaded Web export on GitHub
Pages, built and reviewed entirely through pull requests.

> **Starting from the template?** Replace this file. §2 and §4 below are true of
> any Godot Web build and should survive; everything in angle brackets is a
> placeholder for your game. `scripts/check-constraints.sh` enforces the
> mechanical half of what is written here, reading its expectations from
> `project.conf` — so if you change a rule, change it in both places.

---

## 1. Run this first, always

Every session starts from an empty container with nothing installed.

```bash
scripts/bootstrap.sh
export PATH="$HOME/.godot-toolchain/bin:$PATH"
```

`scripts/bootstrap.sh` is the **single source of truth** for what a correctly
configured environment looks like. CI invokes this exact script, and reads the
Godot version out of it rather than repeating the pin, so there is one
definition rather than two that drift.

Idempotent — a second run is a no-op taking under a second.
`scripts/bootstrap.sh --check` verifies without installing and prints a
per-tool `PASS`/`FAIL` table.

Bumping a version means editing the constants at the top of that script and
nothing else.

---

## 2. Hard technical constraints (non-negotiable)

Engine and platform limits, not style preferences. A PR violating one of these
should be rejected regardless of how good the code is. The first four are true
of **every** Godot Web build; do not relax them for a new game.

| Constraint | Why |
|---|---|
| **No C#/.NET** | C# cannot export to Web in Godot 4 at all. |
| **No multithreading** | The Web target is single-threaded. Godot's threaded Web export needs COOP/COEP headers GitHub Pages cannot serve. Never enable `variant/thread_support`. |
| **No 3D** | 2D only — `Control`, `Node2D`, sprites, tilemaps. |
| **Bounded memory** | Browsers cap WebAssembly memory hard. See §4. |
| **Fixed frame** | The viewport in `project.conf` is the design. Off-shape screens get the same frame centred and letterboxed, never a responsive reflow — that is `stretch/aspect="keep"`. |
| **\<Your input model\>** | e.g. one tap or one click; no multi-touch, no keyboard requirement. |
| **\<Your art direction\>** | e.g. fully monochrome, near-black ink on off-white paper. |

---

## 3. GDScript style conventions

Enforced by `gdlint` (config in `.gdlintrc`). CI fails on any violation.

- **Static typing everywhere.** Annotate every variable, parameter and return
  type. Use `:=` only when the type is obvious from the right-hand side.
- `snake_case` functions and variables; `PascalCase` classes and node names;
  `UPPER_SNAKE_CASE` constants; leading underscore for private members.
- Signal handlers are `_on_<source>_<signal>`. Signals are named for what
  happened, past tense: `taps_changed`, `level_completed`.
- Member order is enforced: `class_name → extends → docstring → signals →
  enums → consts → exports → public vars → private vars → @onready vars →
  methods`. `@onready` comes **after** plain variables; this trips people up.
- Every script opens with a `##` docstring. Comment the *why*, especially for
  constraint-driven decisions.
- Reach into a scene with unique names (`%Counter`), never brittle paths. Wire
  signals in `_ready()` in code, so the connection shows up in the diff rather
  than being buried in a `.tscn`.

---

## 4. Performance and resource guardrails

Concrete, checkable rules, so review can point at a number rather than argue
about whether something "looks reasonable".

- **Never instantiate a collection whose size is driven by data without a hard
  cap.** Any loop that creates nodes must be bounded by a **named constant**,
  never by a data-derived length alone.
- Ceiling: **64 simultaneous nodes** under one gameplay host node. Past that,
  pool and reuse.
- **Prefer one `_draw()` over many nodes** for repeated visual elements. The
  starter screen draws all 25 cells itself rather than spawning 25 children.
  Follow that for anything gridded or repeated.
- Every spawned node needs an owner responsible for freeing it.
- **No unbounded loops.** Every `while` needs a provably terminating condition
  or an explicit iteration cap.
- No allocation inside `_process()` / `_physics_process()` — no `load()`, no
  `instantiate()`, no new `Array`/`Dictionary` per frame. Prefer a finite
  `Tween`; it self-terminates, where a `_process()` loop with a bad exit
  condition hangs a CI runner.
- **Prefer SVG line art.** Rasters are capped by `MAX_RASTER_PX` in
  `project.conf`, and only that big with a stated reason.
- Hold one texture at a time per display slot; do not accumulate frames.
- No `preload()` of an asset set. Bulk content loads lazily by path.

**Two different limits, often confused.** Disk size of the build (what is
served to the browser; GitHub's limits are 100 MB per file and 1 GB per site,
enforced by the `web-export` job) is unrelated to memory while playing (the
WebAssembly heap, far tighter on mobile). Do not reason about one using the
other's numbers.

If your game has no end state, **the risk is a leak**: someone can play
indefinitely, and a build that leaks a little per round is fine in review and
dead after an hour. A test that plays many rounds and asserts node count and
static memory stay flat is worth writing early.

---

## 5. Testing

```bash
scripts/check-constraints.sh
gdlint .
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
godot --headless --path . --quit-after 120 res://scenes/main.tscn
godot --headless --path . --export-release "Web" build/web/index.html
```

- Tests live in `tests/unit/`, named `test_*.gd`, extending `GutTest`.
- **Test the guardrails, not just the happy path.** The assertion that a cell
  count comes from named constants matters more than the one that says tapping
  works.
- Pure logic must stay testable without instantiating a scene. Keep it that
  way — a test that has to spin up a scene is slow and tends to get deleted.

---

## 6. Pull requests

Use `.github/pull_request_template.md`. Every PR states what changed, why, and
how it was tested — concretely. For gameplay changes, open the PR preview build
in a browser and say what you actually did in it.

Required CI checks, all six must pass: `constraints`, `lint`, `unit-tests`,
`smoke-test`, `web-export`, `web-smoke`. None needs a credential — this
repository has no secrets.

`constraints` is the deterministic half of review: it asserts the §2 limits and
the §4 rules that can be checked without judgement. Run it yourself with
`scripts/check-constraints.sh`. Everything needing judgement is the reviewer's
job.

**Every PR needs a review from another person.** You cannot approve your own,
and an agent cannot approve one at all. Auto-merge switches on only when a
human adds the `tested` label, meaning they played the preview.

Files in `.github/CODEOWNERS` additionally require the owner's approval — the
workflows, the bootstrap and settings scripts, the constraint checker,
`.gdlintrc`, `project.godot` and `project.conf`. The last three are listed
because they define what the gates *mean*: relaxing a rule in `.gdlintrc` makes
`lint` pass on code it should reject.

---

## 7. Layout

```
.
├── project.conf                 ← the only per-project config
├── CLAUDE.md                    ← this file
├── project.godot                ← frame, renderer, threads off
├── export_presets.cfg           ← Web preset; thread_support MUST stay false
├── .claude/                     ← SessionStart hook: git identity + bootstrap
├── scripts/
│   ├── bootstrap.sh             ← run first; single source of truth
│   ├── check-constraints.sh     ← the `constraints` gate; run it locally
│   ├── apply-repo-settings.sh   ← branch protection, derived from the remote
│   ├── autoload/                ← GameState, the only autoload
│   ├── game/                    ← pure logic, testable without a scene
│   └── ui/                      ← screens
├── scenes/
├── assets/
├── tests/unit/                  ← GUT suite
├── addons/gut/                  ← installed by bootstrap, git-ignored
└── .github/workflows/           ← the six checks, previews, deploy
```

## 8. The game

\<One paragraph: what the player does, what the loop is, what it is for.\>
