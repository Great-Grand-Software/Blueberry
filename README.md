# blueberry

A monochrome portrait game about ripping pages off a calendar, forever.

Built and reviewed entirely through Claude Code cloud sessions — no local
development machine anywhere in this workflow.

**This is an experimental proof of concept, not a polished game.** The core
loop is deliberately minimal: it exists to be extended by contributors through
pull requests. Parts of it are intentionally left undesigned — read
[`DESIGN.md`](DESIGN.md) §10 before assuming something is missing by accident.

## The loop

A calendar hangs off a single thumbtack on a plain cubicle wall. Tap it and
the page tears loose, tumbles away, and the next one is already underneath.

Points come from **holidays and nothing else** — eight in a year, so most rips
are worth nothing at all. The year on the wall starts at **2026** and climbs
forever; a long run really does reach 4027.

Spend the points in the store on a coarser calendar: **Daily** (365 rips a
year) becomes **Monthly** (12), then **Quarterly** (4), then **Yearly** (1).
Each is a differently shaped object with a different face, and each covers more
of the year per rip. They cost **80, 800 and 8,000 points** — which, since a
year is eight points on every calendar, is ten years, then a hundred, then a
thousand.

Swipe left and right between the calendar, your progress, and the store. It
never ends, and it never caps.

## Getting started (any session, any machine)

```bash
./scripts/bootstrap.sh
export PATH="$HOME/.blueberry/bin:$PATH"
```

That installs a pinned Godot, its export templates, gdlint, and GUT, then
prints a pass/fail table of the environment. It is idempotent, and it is the
same script CI runs.

Then read:

| File | What it is |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | The rules — constraints, style, guardrails |
| [`DESIGN.md`](DESIGN.md) | The intent, and what is deliberately open |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The PR loop, previews, and testing |
| [`SETUP.md`](SETUP.md) | One-time repo setup needing admin rights |

## The checks

| Check | Command |
|---|---|
| `lint` | `gdlint .` |
| `unit-tests` | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` |
| `smoke-test` | `godot --headless --path . --quit-after 120 res://scenes/main_menu.tscn` |
| `web-export` | `godot --headless --path . --export-release "Web" build/web/index.html` |

All four are required status checks on `main`. Every PR also gets a playable
preview build deployed to a unique URL, so gameplay changes can be reviewed in
a real browser without installing anything.

## Constraints

2D only · no threads · GDScript only · bounded memory · portrait 3:4 in a
fixed letterboxed frame · one point of contact · fully monochrome · no
unbounded loops. These are engine and platform limits, not preferences —
see [`CLAUDE.md`](CLAUDE.md) §2.
