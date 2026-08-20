# blueberry

Godot 4 / GDScript 2D portrait game, built and reviewed entirely through
Claude Code cloud sessions. There is no local development machine anywhere in
this workflow.

**Read `DESIGN.md` too.** This file is the rules. `DESIGN.md` is the intent —
and, importantly, the list of things left undesigned on purpose. Do not fill
an open slot without saying so.

---

## 0. Settled decisions — do not re-litigate

**This section exists because an agent already wasted a maintainer's time
arguing with each of these. If you are an agent working on this repo, treat
them as facts about the project, not as open questions.**

| Settled | Do not |
|---|---|
| The game ships as a **Godot Web export on GitHub Pages**. | Propose itch.io, Netlify, Vercel, a zip download, "run it locally", or any other host. The static-page constraint is deliberate and permanent. |
| **Build size up to 1 GB is fine.** Today it is ~40 MB. | Call the build "too large", refuse to commit it, propose stripping assets to shrink it, or route around pushing it. CI enforces the real limits; if CI passes, the size is acceptable. |
| **Push the real build.** | Substitute an HTML/JS mock, a screenshot, or a description when asked to make the game testable. A prototype is never a deliverable unless it was explicitly requested. |
| **Single-threaded Web export only.** | Enable `variant/thread_support`, or suggest COOP/COEP headers. GitHub Pages cannot serve them. This is why the build works at all. |
| Large binaries belong in git. | Suggest Git LFS, an external CDN, or a release asset instead of the `gh-pages` branch. |

Two facts that make the size question a non-issue, and that an agent should
check before worrying about it:

- **`index.wasm` (~39 MB) is the engine template. It is byte-identical between
  builds.** Git stores content once by hash, so a new build adds roughly the
  size of `index.pck` — about 100 KB — not 39 MB.
- GitHub's actual limits are **100 MB per file** and **1 GB per Pages site**.
  Both are enforced by the `web-export` job, which fails the build rather than
  leaving anyone to find out later.

If you believe one of these decisions is genuinely wrong, say so **once**, in a
sentence, with the specific evidence — then do the task as specified. Do not
re-raise it, and do not quietly do something else instead.

---

## 1. Run this first, always

Every session starts from an empty container with nothing installed.

```bash
scripts/bootstrap.sh
export PATH="$HOME/.blueberry/bin:$PATH"
```

`scripts/bootstrap.sh` is the **single source of truth** for what a correctly
configured environment looks like. CI invokes this exact script to prepare its
own runners, so there is one definition, not two that can drift.

| Tool | Pinned version |
|---|---|
| Godot (non-Mono, headless-capable) | `4.7.1-stable` |
| Godot export templates | `4.7.1.stable` (incl. `web_nothreads_*`) |
| gdtoolkit (`gdlint`, `gdformat`) | `4.5.0` |
| GUT test addon | `9.7.1` |

Idempotent — a second run is a no-op taking under a second.
`scripts/bootstrap.sh --check` verifies without installing, exits non-zero on
any mismatch, and prints a per-tool `PASS`/`FAIL` table. That is what CI uses
as its guard.

Bumping a version means editing the constants at the top of that script and
nothing else.

---

## 2. Hard technical constraints (non-negotiable)

Engine and platform limits, not style preferences. A PR violating one of these
should be rejected regardless of how good the code is.

| Constraint | Why |
|---|---|
| **No 3D** | 2D only — `Control`, `Node2D`, sprites, tilemaps. No 3D meshes, physics, or lighting. |
| **No multithreading** | The Web target is single-threaded. Godot's threaded Web export needs COOP/COEP headers GitHub Pages cannot serve. Never enable `variant/thread_support`; never write code assuming worker threads. |
| **No C#/.NET** | GDScript only. C# cannot export to Web in Godot 4 at all. |
| **Bounded memory** | Browsers cap WebAssembly memory hard. See §4. |
| **Portrait 3:4, fixed frame** | Viewport is `720x960`. Off-shape screens get the same frame **centred and letterboxed**, never a responsive reflow. That is `stretch/aspect="keep"`, and it is the design, not a placeholder. |
| **Single point of contact** | One tap or one click. No multi-touch gestures, no keyboard or gamepad requirement. |
| **Fully monochrome** | No colour anywhere, including new assets. Near-black ink, off-white paper, dark ground. |
| **No unbounded loops or spawn logic** | Anywhere in gameplay code. See §4. |

---

## 3. GDScript style conventions

Enforced by `gdlint` (config in `.gdlintrc`). CI fails on any violation.

**Typing**

- **Static typing everywhere.** Annotate every variable, parameter, and return
  type: `var _pages: Array[CalendarPage] = []`, `func rip_off() -> void:`.
- Use `:=` inference only when the type is obvious from the right-hand side
  (`var config := ConfigFile.new()`). Otherwise write the type out.
- Typed collections over untyped. Type loop variables too:
  `for page: CalendarPage in _pages:`.

**Naming**

- `snake_case` functions and variables; `PascalCase` classes, `class_name`
  values, and node names; `UPPER_SNAKE_CASE` constants.
- Private members — anything outside a node's external contract — take a
  leading underscore: `_is_folding`, `_restack()`.
- Signal handlers are `_on_<source>_<signal>`: `_on_pause_button_pressed`.
- Signals are named for what happened, past tense: `day_tapped`,
  `month_completed`, `fold_finished`.

**File and member order**

`gdlint`'s `class-definitions-order` is enforced:

```
class_name → extends → docstring → signals → enums → consts →
exports → public vars → private vars → @onready vars → methods
```

`@onready` variables come **after** plain variables. This trips people up.

**Documentation**

- Every script opens with a `##` docstring saying what it is and why it exists.
- Public methods get a `##` comment; private ones when the name isn't enough.
- Comment the *why*. Constraint-driven decisions — the page cap, the uniform
  30-day month, drawing the grid in one node — must say what drove them.

**Scene vs. script organization**

- `scenes/` (`.tscn`), `scripts/` (`.gd`), `assets/`, `tests/`, `addons/`
  (bootstrap-managed, git-ignored).
- Scripts mirror their scene: `scenes/game.tscn` →
  `scripts/game/game_screen.gd`.
- Grouped by role: `scripts/game/`, `scripts/ui/`, `scripts/autoload/`.
- Reach into a scene with unique names (`%CalendarView`), never brittle paths.
- Wire signals in `_ready()` in code, so the connection shows up in the diff
  rather than being buried in a `.tscn`.
- `GameState` is the **only** autoload. Adding another needs a good reason.

---

## 4. Performance and resource guardrails

Concrete, checkable rules, so review can point at a number rather than argue
about whether something "looks reasonable".

**Spawning and node counts**

- **Never instantiate a collection whose size is driven by data without a hard
  cap.** The calendar runs forever; the node count must not grow.
  `CalendarView.MAX_LIVE_PAGES = 2` — the page being ripped and the one
  underneath it, nothing more. Pages already falling are capped separately by
  `CalendarView.MAX_FALLING_PAGES = 3`, because a tapper faster than the fall
  would otherwise outrun the tween that frees them.
- Any loop that creates nodes must be bounded by a **named constant**, never
  by a data-derived length alone.
- Ceiling: **64 simultaneous nodes** under one gameplay host node. Past that,
  pool and reuse.
- **Prefer one `_draw()` over many nodes** for repeated visual elements.
  `CalendarPage` draws its whole face itself — a month grid, three months of
  dots, or twelve month tracks — rather than a node per cell, so a yearly page
  costs exactly what a daily one does. `StatsView` and `StoreView` draw their
  rows and panels the same way. Follow this pattern for anything gridded or
  repeated.
- Every spawned node needs an owner responsible for freeing it. Nodes that
  animate themselves out must `queue_free()` at the end of that animation.

**Loops**

- **No unbounded loops.** Every `while` needs a provably terminating condition
  or an explicit iteration cap.
- No allocation inside `_process()` or `_physics_process()`. No `load()`, no
  `instantiate()`, no new `Array`/`Dictionary` per frame.
- Prefer a finite `Tween` over per-frame animation. Tweens self-terminate; a
  `_process()` loop with a bad exit condition hangs a CI runner. (Every CI job
  has a hard timeout as a backstop, and the smoke test has its own 90s
  per-scene timeout — because a broken scene really does hang the engine.)

**Two different limits, often confused**

These measure unrelated things. Do not reason about one using the other's
numbers.

| | Disk size of the build | Memory while playing |
|---|---|---|
| What | the files served to the browser | the WebAssembly heap in the player's tab |
| Limits | 100 MB per file, 1 GB per site (GitHub's) | whatever the browser allows; far tighter on mobile |
| Grows with | assets and code you add | leaks, unbounded spawning, accumulating references |
| Enforced by | the `web-export` size gate | `tests/unit/test_memory_growth.gd` and the guardrails below |

The build is currently ~40 MB on disk, of which 39.5 MB is the engine itself —
a fixed cost that does not grow as content is added. The actual game
(`index.pck`) is under 100 KB.

Disk size has never been the risk here. **The risk is a leak**: the game has no
end state, so someone can tap at it indefinitely, and a build that leaks a
little per month is fine in review and dead after an hour.
`test_memory_growth.gd` plays twelve months and asserts node count and static
memory both stay flat. Keep it that way.

**Assets and memory**

- **Prefer SVG line art.** The twelve month drawings are stroke-only SVGs of
  300–1700 bytes each. New imagery should match.
- **Rasters: 512×512 maximum**, and only that big with a stated reason.
- **Hold one texture at a time per display slot.** `MonthImage` replaces
  `texture` when the page changes month and never accumulates frames. Only the
  pages currently alive hold one at all.
- No `preload()` of an asset set. `preload` only single scenes/scripts needed
  at load; bulk content loads lazily by path.
- New assets: justify the byte cost in the PR description.

**Input**

- All gameplay input reduces to one point of contact, and **`ViewPager` is the
  only thing that reads it**. `ViewPager._input` accepts that one contact
  pressed, moved and released — `InputEventScreenTouch` and
  `InputEventScreenDrag` at index 0, or `InputEventMouseButton` and
  `InputEventMouseMotion` for the left button — and nothing else. It decides
  whether the contact was a swipe or a tap and hands taps on to the view in
  front. Nothing underneath does its own hit-testing: a rip and a swipe are the
  same finger, and two readers of it would both claim it. Holding and moving is
  one contact, not a gesture; a second index is ignored everywhere.
- No handler requiring two simultaneous events, and no gesture events
  (`InputEventPanGesture`, `InputEventMagnifyGesture`) anywhere.
- No keyboard or gamepad as the *only* way to do anything. Pause is an
  on-screen button, not the Escape key.

---

## 5. Testing

```bash
gdlint .
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
godot --headless --path . --quit-after 120 res://scenes/main_menu.tscn
godot --headless --path . --export-release "Web" build/web/index.html
```

- Tests live in `tests/unit/`, named `test_*.gd`, extending `GutTest`.
- **Test the guardrails, not just the happy path.**
  `test_calendar_view.gd` asserts pinned pages never exceed `MAX_LIVE_PAGES`
  across sixty rips and that ripping faster than the fall cannot pile sheets
  up; `test_calendar_tier.gd` asserts a year of rips lands exactly on New Year
  on all four tiers; `test_view_pager.gd` asserts a swipe never also rips the
  page under it. Those are the tests that matter most here.
- Pure logic (`CalendarData`, `HolidayData`, `CalendarTier`, `DayCounter`) must
  stay testable without instantiating a scene. Keep it that way.

---

## 6. Pull requests

Use `.github/pull_request_template.md`. Every PR states what changed, why, and
how it was tested — concretely. For gameplay changes, open the PR preview build
in a browser and say what you actually did in it.

Required CI checks, all six must pass: `constraints`, `lint`, `unit-tests`,
`smoke-test`, `web-export`, `web-smoke`. None of them needs a credential — this
repository has no secrets. CI also deploys a playable preview to a per-PR URL,
stamped with its commit so a tester can tell builds apart.

`constraints` is the deterministic half of review: it asserts the §2 hard
constraints and the §4 limits that can be checked without judgement. Run it
yourself with `scripts/check-constraints.sh`. Everything needing judgement is
the reviewer's job.

**Every PR needs a review from another person.** You cannot approve your own,
and an agent cannot approve one at all. Auto-merge then switches on only when a
human adds the `tested` label, meaning they played the preview. See
`CONTRIBUTING.md` for the full loop.

Files in `.github/CODEOWNERS` — this file, the CI workflows, the bootstrap and
repo-settings scripts, the constraint checker, `.gdlintrc`, `project.godot`,
and `.claude/` — additionally require Talon's personal approval.

**If your PR fills one of the open slots in `DESIGN.md` §9, update that file in
the same PR.** An open slot quietly filled is worse than one still open.

---

## 7. Layout

```
.
├── CLAUDE.md                    ← rules (owned by Talon)
├── DESIGN.md                    ← intent + deliberately open slots
├── SETUP.md                     ← one-time repo setup needing admin rights
├── project.godot                ← 720x960 portrait, aspect=keep, threads off
├── export_presets.cfg           ← Web preset; thread_support MUST stay false
├── .claude/                     ← SessionStart hook: git identity + bootstrap
├── scripts/
│   ├── bootstrap.sh             ← Phase 0, run first (owned by Talon)
│   ├── apply-repo-settings.sh   ← branch protection (owned by Talon)
│   ├── check-constraints.sh     ← the `constraints` CI gate; run it locally
│   ├── autoload/game_state.gd   ← points, tier, calendar position (only autoload)
│   ├── game/                    ← calendar_data, holiday_data, calendar_tier,
│   │                              day_counter, calendar_page, month_image,
│   │                              calendar_view, game_screen
│   └── ui/                      ← main_menu, pause_overlay, header_bar,
│                                  view_pager, stats_view, store_view
├── scenes/                      ← main_menu, game, calendar_page
├── assets/images/months/        ← twelve SVG line drawings
├── tests/unit/                  ← GUT suite
├── addons/gut/                  ← installed by bootstrap, git-ignored
└── .github/workflows/           ← CI (owned by Talon)
```

## 8. The game

A calendar hangs off a single thumbtack on a plain cubicle wall. Tap it to rip
the page off; it tears loose and tumbles away, revealing the next one. Points
come from holidays and nothing else — eight a year, so most rips are worth
nothing. Spend them in the store on a coarser calendar: monthly, then
quarterly, then yearly, each one a different object that covers more of the
year per rip. Swipe between the calendar, your progress, and the store. It
never ends and never caps.

Full intent, screen geometry, and the open slots: **`DESIGN.md`**.
