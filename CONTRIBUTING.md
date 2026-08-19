# Contributing

The whole loop, end to end, and the places it can bite you.

---

## The flow

1. **Branch in this repo.** Not a fork — see the warning below.
2. Make your change. Your agent should run `scripts/bootstrap.sh` first; it is
   the only setup step, and it is idempotent.
3. Open a PR. Fill in the template: what changed, why, how you tested it.
4. **CI runs five required checks** and builds a playable preview.
5. **A bot reviews the PR** against `CLAUDE.md` and either approves or requests
   changes.
6. **A human opens the preview URL and plays it.** This is the point of the
   whole pipeline. CI proves the build is not broken; only a person can say
   whether it is *right*.
7. Push more commits until it is what you wanted. Each push replaces the
   preview in place.
8. When you are happy, **add the `tested` label**. That enables auto-merge, and
   the PR merges itself once every check and review is green.

Step 8 is deliberately a human action. Nothing merges because a bot approved
it.

---

## ⚠️ Branch here, do not fork

GitHub does not give fork PRs access to repository secrets, and it gives them a
read-only token. In a fork PR:

- the **bot reviewer cannot run** — no `ANTHROPIC_API_KEY`, so no approval, so
  the PR cannot satisfy its required review;
- the **preview cannot deploy** — no write access to `gh-pages`.

Everyone on the project has Write access to this repo, so just push a branch
here. If an outside contribution ever arrives as a fork, a maintainer has to
re-push the branch into this repo before the pipeline will work on it.

---

## What CI checks

| Check | What it proves |
|---|---|
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

## What the bot reviewer will hold you to

It reads `CLAUDE.md` and checks the diff against it — the hard constraints
(§2), the performance guardrails (§4), the style conventions (§3), test
coverage, and whether the PR description says how it was verified.

It requests changes for a hard-constraint violation regardless of code quality.
The constraints are engine and platform limits, not preferences.

---

## Files that need Talon's approval

`.github/CODEOWNERS` lists them: `CLAUDE.md`, the CI workflows, the bootstrap
script, the repo-settings script, and the build stamp script. A PR touching any
of them needs his review in addition to the bot's. Ordinary gameplay PRs are
unaffected.

---

## Filling an open slot

`DESIGN.md` §7 lists what is deliberately undesigned — milestones, whether the
image theme ever changes, sound and animation, meta systems. If your PR decides
one of those, **update `DESIGN.md` in the same PR** and say what you decided.
An open slot quietly filled is worse than one still open.
