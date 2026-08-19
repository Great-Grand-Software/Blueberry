# blueberry

A monochrome portrait game about crossing days off a calendar, forever.

Built and reviewed entirely through Claude Code cloud sessions — no local
development machine anywhere in this workflow.

**This is an experimental proof of concept, not a polished game.** The core
loop is deliberately minimal: it exists to be extended by contributors through
pull requests. Parts of it are intentionally left undesigned — read
[`DESIGN.md`](DESIGN.md) §7 before assuming something is missing by accident.

## The loop

Tap a day in the calendar grid to cross it off with an X. Thirty taps finish
the month; the page folds down, revealing the next month and its line drawing.
Your score is every day you have ever tapped, shown across six units at once —
days, months, years, decades, centuries, millennia. It never ends, and it never
caps.

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
