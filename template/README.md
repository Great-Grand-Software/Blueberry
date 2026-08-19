# godot-web-template

A Godot 4 web game that builds, tests, deploys and is **playable in a browser**
from the moment you clone it — with no secrets, no API keys, and no paid
services.

Clone it, replace the placeholder game, and every pull request gets its own
playable URL.

---

## What you get

| | |
|---|---|
| **Six CI checks** | constraints, lint, unit tests, headless boot, Web export, real-browser boot |
| **A playable preview per PR** | posted as a comment, deleted when the PR closes |
| **Automatic deploy** | every merge to `main` republishes the public page |
| **Build provenance** | a stamp in the corner tells you which commit you are playing |
| **Branch protection as code** | one script, checked in and reviewable |
| **Zero secrets** | every job runs on the token GitHub mints per run |

That last row is the one that makes this cheap to reuse. There is nothing to
provision, expire, or pay for.

---

## Start a new game from this template

**1. Make the repo.** Click **Use this template → Create a new repository** on
GitHub. Make it **public** — Pages on a private repo needs a paid plan, and the
previews depend on Pages.

**2. Get it running.**

```bash
git clone https://github.com/<owner>/<your-repo>.git
cd <your-repo>
scripts/bootstrap.sh
export PATH="$HOME/.godot-toolchain/bin:$PATH"
```

`bootstrap.sh` installs Godot, the export templates, gdtoolkit and GUT at
pinned versions. It is idempotent and takes about ninety seconds the first
time, under a second after that. It is the single source of truth for the
environment — CI runs this exact script, so there is one definition rather than
two that drift.

**3. Push to `main` and let CI run once.** Required status checks have to be
seen by GitHub by name before they can be required, so the first run has to
happen before step 5.

**4. Turn on Pages.** Settings → Pages → Source: **Deploy from a branch** →
branch **`gh-pages`**, folder **`/ (root)`**.

> **This is the step everyone gets wrong.** The dropdown defaults to `main`.
> `main` holds your *source*, which has no `index.html`, so Jekyll renders your
> README as a text page and the game never appears. It must be `gh-pages`.
> That branch does not exist until the first deploy runs, which is why this
> step comes after step 3, not before.

**5. Lock the branch.**

```bash
export GH_TOKEN=<a token with admin rights on the repo>
scripts/apply-repo-settings.sh plan     # prints what it will write, calls nothing
scripts/apply-repo-settings.sh apply
scripts/apply-repo-settings.sh verify   # exit 0 and all PASS
```

Owner and repo are read from your git remote, so there is nothing to edit.

Your game is now at `https://<owner>.github.io/<your-repo>/`.

---

## Make it your game

**Edit `project.conf`.** It is the only file with project-specific values in
it — frame size, entry scenes, and the guardrail budgets. Everything in
`scripts/` and `.github/` is project-neutral and carries forward untouched.

```bash
ENTRY_SCENES="res://scenes/main_menu.tscn res://scenes/game.tscn"
VIEWPORT_WIDTH=720                      # asserted against project.godot
VIEWPORT_HEIGHT=960
MAX_AUTOLOADS=1
MAX_RASTER_PX=512
```

**Then replace the placeholder.** Delete `scripts/game/`, `scenes/game.tscn`
and the tests for them, and write yours. Keep `scripts/autoload/` down to one
file, or raise `MAX_AUTOLOADS` deliberately.

**Keep the main menu.** `scenes/main_menu.tscn` is the boot scene and ships
with a working START button that hands off to `scenes/game.tscn`, plus a QUIT
that hides itself on the web build where quitting means nothing. Every game
from this template gets a deliberate entry point rather than dropping the
player straight into play. Change *what START leads to*, not whether it exists
— `tests/unit/test_main_menu.gd` asserts the button is there and that its
target scene actually resolves, because a START button pointing at a missing
scene looks fine in review and dead-ends the player.

**Then rewrite `CLAUDE.md`.** It ships with the constraints that are true of
*any* Godot Web build — no C#, no threads, no 3D — plus placeholders for the
ones specific to your game. Agents working in the repo read it on entry, and
the `constraints` check enforces the mechanical half of it.

The placeholder game is a 5×5 grid you tap. It exists to prove the pipeline
end to end, and it is deliberately small enough to delete without regret.

---

## Daily loop

1. Branch **in this repo** — not a fork. Fork PRs get a read-only token, so
   the preview cannot deploy.
2. Push. CI runs six checks and builds a preview.
3. A bot comments the preview URL. **Open it and play.** CI proves the build
   is not broken; only a person can say whether it is *right*.
4. Get a review from another person. You cannot approve your own PR.
5. Add the `tested` label. Auto-merge takes it from there once checks and the
   review are green.

Run the fast checks yourself before pushing:

```bash
scripts/check-constraints.sh
gdlint .
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

---

## Why it is built this way

**No secrets.** An earlier version of this pipeline used an LLM reviewer, which
needed an API key, which needed billing and a decision about whose account paid
for it. Replacing the mechanical half of that review with
`scripts/check-constraints.sh` — a deterministic script with no network
access — removed the last credential from the repo. What remained was
judgement, which is what human review is for.

**Checks that fail for the right reason.** `check-constraints.sh` only asserts
what can be asserted without false positives. A check that cries wolf gets
ignored, and an ignored check is worse than no check.

**Config the gates read is gated too.** `.gdlintrc` *is* the lint gate —
relaxing a rule there makes `lint` pass on code it should reject. So it sits in
`CODEOWNERS` alongside the workflows, and so does `project.godot`, which
carries constraints no other job re-derives.

**One source of truth for the environment.** Tool versions live in
`scripts/bootstrap.sh` and nowhere else. CI reads the Godot version out of that
file rather than repeating it, and the toolchain cache key is a hash of it, so
a version bump invalidates the cache by construction.

---

## Layout

```
.
├── project.conf              ← the only per-project file
├── CLAUDE.md                 ← rules for agents and reviewers
├── project.godot             ← frame, renderer, threads off
├── export_presets.cfg        ← Web preset; thread_support MUST stay false
├── .claude/                  ← SessionStart hook: git identity + bootstrap
├── scripts/
│   ├── bootstrap.sh          ← run first; single source of truth
│   ├── check-constraints.sh  ← the `constraints` gate; run it locally
│   ├── apply-repo-settings.sh← branch protection, derived from your remote
│   ├── autoload/             ← GameState, the only autoload
│   ├── game/                 ← pure logic, testable without a scene
│   └── ui/                   ← screens
├── scenes/                   ← main_menu.tscn (boot) + game.tscn
├── tests/unit/               ← GUT suite
└── .github/workflows/        ← the six checks, previews, deploy
```

---

## Gotchas worth knowing before you hit them

- **Pages must point at `gh-pages`.** See step 4. It is the single most common
  failure, and it looks like a broken build when it is a wrong dropdown.
- **The preview URL is case-sensitive in its repo path.** The owner is
  lowercased because a hostname must be; the repo is spelled as GitHub spells
  it. The Pages settings page shows the authoritative URL.
- **Pushing twice quickly cancels the first CI run.** `cancel-in-progress` is
  deliberate, but a cancelled run reports no failures *and* no successes — so a
  PR can sit unmergeable with nothing red on it. Look for "cancelled", not just
  "failed".
- **A merged PR's preview is deleted.** That is by design: its build becomes
  the root URL. The link on a merged PR will 404.
- **`git` identity in a fresh container.** The SessionStart hook sets it from
  whoever the session is authenticated as, so commits link to real accounts
  instead of all landing under one anonymous name. Working outside Claude Code,
  set `user.email` to your `users.noreply.github.com` address yourself.
