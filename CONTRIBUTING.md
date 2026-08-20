# Contributing

The whole loop, end to end, and the places it can bite you.

---

## Before your first PR: make your commits yours

A fresh cloud container has no git identity, so commits default to
`Claude <noreply@anthropic.com>`. GitHub links a commit to an account by
matching the author email, and that address matches nobody — so the commit
shows as an unlinked "Claude", with no avatar, no profile link, and no
contribution credit. With several people working this way, `git log` and
`git blame` stop telling you whose work is whose.

`.claude/settings.json` carries a SessionStart hook that sets this
automatically from whoever's account the session is authenticated as, so in a
Claude Code session there is nothing to do.

Working any other way, set it yourself once per clone:

```bash
git config user.name  "Your Name"
git config user.email "<id>+<username>@users.noreply.github.com"
```

Your `users.noreply.github.com` address is on GitHub under Settings → Emails.
It links the commit to your account without publishing a private address.

When an agent wrote the change, keep a trailer on the commit so that stays
visible. You are the author and remain accountable for it; the agent is a
co-author:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## The flow

1. **Branch in this repo.** Not a fork — see the warning below.
2. Make your change. Your agent should run `scripts/bootstrap.sh` first; it is
   the only setup step, and it is idempotent.
3. Open a PR. Fill in the template: what changed, why, how you tested it.
4. **CI runs six required checks** and builds a playable preview.
5. **Another developer reviews it** and approves or requests changes. You
   cannot approve your own PR, and that is the point — a second pair of eyes
   that did not write the code.
6. **A human opens the preview URL and plays it.** This is the point of the
   whole pipeline. CI proves the build is not broken; only a person can say
   whether it is *right*.
7. Push more commits until it is what you wanted. Each push replaces the
   preview in place, and dismisses any approval already on the PR.
8. When you are happy, **add the `tested` label**. That enables auto-merge, and
   the PR merges itself once every check and the review are green.

Steps 5 and 8 are both deliberately human. An agent can write the change and
open the PR; it cannot review its own work into `main`.

---

## ⚠️ Branch here, do not fork

GitHub gives fork PRs a read-only token. In a fork PR the **preview cannot
deploy**, because publishing it needs write access to `gh-pages` — and the
preview is the thing your reviewer actually plays.

Everyone on the project has Write access to this repo, so just push a branch
here. If an outside contribution ever arrives as a fork, a maintainer has to
re-push the branch into this repo before the pipeline will work on it.

---

## What CI checks

| Check | What it proves |
|---|---|
| `constraints` | the `CLAUDE.md` §2 hard constraints hold — no C#, no 3D, no threading, portrait frame intact |
| `lint` | `gdlint` is clean across the project |
| `unit-tests` | the GUT suite passes headless |
| `smoke-test` | every entry-point scene boots in the engine without errors |
| `web-export` | the Web export completes, is single-threaded, and is within the size budget |
| `web-smoke` | **the exported build actually boots in a real browser** |

That last one matters more than it sounds. A passing `smoke-test` only proves
the game runs in desktop Godot. `web-smoke` loads the real wasm in Chromium and
asserts the engine starts, reports a single-threaded build, gets a WebGL
context, and logs no errors — which is the only way to catch a failure that
exists solely in the Web build.

None of these need a credential. Every job runs on the per-run token GitHub
mints itself, so there are no secrets in this repository to leak, rotate, or
pay for.

Every job has a hard timeout. A runaway `_process()` loop fails the job rather
than hanging a runner.

---

## The preview build

Once CI passes, a comment appears on the PR with a URL. Open it on a phone, or
narrow your desktop window — the game is portrait 3:4 and letterboxes
everywhere else.

Each build carries a **stamp in the bottom-right corner**: the PR number, the
short commit SHA, and the build time. Use it. When a preview is replaced in
place, the stamp is the only way to be sure you are not looking at a cached
copy of the previous build. Quote it when reporting what you saw.

`build-info.json` next to the page carries the same information for tooling.

If the stamp shows an older commit than you expect, hard-refresh
(<kbd>Ctrl/Cmd</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd>). Pages serves with
revalidation, but a phone browser can hold a stale copy.

Previews are deleted from `gh-pages` when the PR closes. The `main` build is
always published at the Pages root.

---

## What review holds you to

Two layers, doing different jobs.

**`constraints` checks the mechanical half** — no C#/.NET sources, no 3D types,
no threading primitives, the portrait viewport and single-threaded settings in
`project.godot`, one autoload, rasters within 512×512. It is deterministic and
needs nothing installed, so run it yourself before you push:

```bash
scripts/check-constraints.sh
```

**Your reviewer checks the half that needs judgement**, against `CLAUDE.md`:
the §4 performance guardrails (is that spawn loop really bounded by a *named
constant*?), the §3 conventions `gdlint` does not cover, whether new gameplay
logic came with GUT coverage, and whether the PR description says how it was
actually verified.

A hard-constraint violation is not negotiable regardless of how good the code
is. Those are engine and platform limits, not preferences.

### Reviewing someone else's PR

- Read the diff against `CLAUDE.md`, not against instinct.
- Open the preview and play it. An approval that skipped the preview is not
  worth much on a gameplay change.
- Request changes for any §2 or §4 violation. Say which rule and cite the line.
- Do not re-flag what `gdlint` or `constraints` already catches; CI said it
  once.

---

## Files that need Talon's approval

`.github/CODEOWNERS` lists them: `CLAUDE.md`, the CI workflows, `CODEOWNERS`
itself, the build stamp script, the repo-settings script, the bootstrap script,
`.gdlintrc`, and `project.godot`.

A PR touching any of them needs his review in addition to your reviewer's. The
last two are on the list because they define what the gates *mean* — relaxing
a rule in `.gdlintrc` makes `lint` pass on code it should reject, and
`project.godot` carries constraints the rest of CI does not re-derive.

Ordinary gameplay PRs are unaffected. That is deliberate: there is no catch-all
rule, so day-to-day work is never gated on one person.

---

## Filling an open slot

`DESIGN.md` §10 lists what is deliberately undesigned — milestones, whether the
image theme ever changes, sound and animation, meta systems. If your PR decides
one of those, **update `DESIGN.md` in the same PR** and say what you decided.
An open slot quietly filled is worse than one still open.
