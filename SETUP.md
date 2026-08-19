# One-time repo setup

Everything here needs org-owner or repo-admin rights, so it cannot be done by
an agent session. Work top to bottom; each step says how to confirm it worked.

## Where this stands

Verified on a real GitHub runner, 2026-08-19:

| | |
|---|---|
| Tree migrated | 80 files, every blob hash and file mode matching the staging tree |
| CI, all jobs | `constraints`, `lint`, `unit-tests`, `smoke-test`, `web-export`, `web-smoke` — green in ~2 min |
| `deploy-main` | created `gh-pages` and redeployed on the next push |
| Build stamp | `build-info.json` matches the deployed commit |
| Published size | 38.07 MB total, 37.68 MB of it `index.wasm` |
| Secrets required | **none** — every job runs on GitHub's per-run token |

Still outstanding: steps 2, 3, 4 and 6 below. Until step 3 runs, `main` has
**no protection at all** — force-pushable, deletable, and directly pushable by
anyone with Write. Nobody but Talon has access yet, so nothing is exposed
today, but **apply step 3 before inviting anyone**, not after.

> **Where this tree came from.** It was built in a Claude Code session bound to
> `talonbaker/AoC`, which could not reach the `Great-Grand-Software` org at all:
>
> - `create_repository` → **403 "Resource not accessible by integration"**.
> - `add_repo` → **"cross-tier adds are not supported in v1"** — a session can
>   only attach repos owned by the owner it started with.
>
> So the tree was staged under `blueberry/` in that repo, built never to depend
> on that location, and lifted out wholesale later. The lift has since been
> done, from a session holding both repos: the directory's contents became this
> repo's root, with every blob hash and file mode verified against the source.

## 1. Create the repository — done

`Great-Grand-Software/Blueberry` exists and holds this tree.

It must be **public**: GitHub Pages on a private repo requires a paid plan, and
the per-PR preview builds depend on Pages. It currently is.

## 2. Install the Claude GitHub App

From a Claude Code terminal session, run `/install-github-app`, or install it
manually from https://github.com/apps/claude. Grant it access to
`Great-Grand-Software/Blueberry`. You must be a repo admin.

This is **not** needed by CI — no workflow calls Anthropic. It is what lets
each developer's Claude Code cloud session reach this repo. Confirm it when you
add the second developer: if their session can clone but every push is refused
by the git proxy, this is why.

**Confirm:** the app appears under Settings → GitHub Apps for the repo.

## 3. Apply branch protection and merge policy

> **This script cannot be run from a Claude Code agent session.** Those
> sessions reach GitHub through a proxy that refuses direct
> `api.github.com/repos/*` requests — which is every call this script makes.
> Run it from a machine with ordinary network access, using a PAT with admin
> rights on the repo. The `plan` subcommand makes no API calls and needs no
> token, so an agent can still show you exactly what `apply` would write.
>
> Be aware that `verify` prints `FAIL` for every setting when it cannot *read*
> the repo, which is indistinguishable from the settings being wrong. Confirm
> you are getting real API responses before acting on a failing `verify`.

```bash
export GH_TOKEN=<a token with repo admin rights>
./scripts/apply-repo-settings.sh plan     # review what it will do
./scripts/apply-repo-settings.sh apply
./scripts/apply-repo-settings.sh verify
```

This sets: PRs required on `main`; the six CI checks required; 1 approving
review; CODEOWNERS binding; admins bound too; squash-only merges; auto-merge
on; auto-delete branch on merge; no force pushes; no deletions.

**Order matters.** Required status checks must have been seen by GitHub at
least once before they can be required by name, or the call fails on unknown
contexts. CI has now run on `main`, so all six are known.

**Confirm:** `verify` exits 0 and prints all `PASS`.

## 3a. Godot-on-Pages is proven, not assumed

The single-threaded Web export has been published to GitHub Pages and verified
end to end, so this pipeline is known to work before anyone depends on it:

- The published `index.wasm` is byte-identical to `web_nothreads_release.zip`,
  confirming the single-threaded template. A threaded build would not run on
  Pages at all, because it needs COOP/COEP headers Pages cannot serve.
- The engine boots in Chromium and reports
  `Emscripten 4.0.20, single-threaded, no GDExtension support`.
- WebGL 2.0 context acquired; menu renders letterboxed at 3:4; `QUIT` correctly
  hidden by `OS.has_feature("web")`; `START` enters the game; taps cross off
  days and the odometer counts them; pause overlay opens. Zero console errors.
- The same check was re-run against the bytes cloned back *from GitHub*, not
  just the local build, so what is published is what was tested.

Build size is ~38 MB, nearly all `index.wasm` — well inside GitHub's 100 MB
file limit and the 1 GB Pages limit, but a slow first load on mobile data.
Pages serves it compressed.

## 4. Enable GitHub Pages

`gh-pages` already exists — `deploy-main` created it and has published `main`
to it. So this is now a single step:

Settings → Pages → Source: *Deploy from a branch* → `gh-pages` / `/ (root)`.

The site will be at `https://great-grand-software.github.io/Blueberry/`, and
per-PR previews at `…/Blueberry/pr-<N>/`. Note the capital B: the preview
workflow lowercases the owner, which a hostname requires, but uses the repo
name as GitHub spells it.

**Confirm:** that URL loads and the game plays.

## 5. Know what merges by itself

`.github/workflows/auto-merge.yml` switches GitHub's native auto-merge on for a
PR **only once someone adds the `tested` label**. The PR then merges itself,
squashed, as soon as the six required checks pass and its approving review
lands. Nothing bypasses branch protection — GitHub does the merging only when
every rule is satisfied.

Worth knowing: anyone with Write can apply that label, including their agent.
It is a discipline, not an enforced control. The enforced control is the
required review, which a person has to give.

To hold a PR back: open it as a draft, or click auto-merge off.
To turn the behavior off entirely, delete that workflow.

## 6. Org permissions, and adding a developer

The model is ordinary GitHub: everyone authenticates as themselves, nobody
shares a credential, and peer review is the gate.

- Talon: sole **Org Owner**.
- Everyone else: **Org Member**, with repo access granted through a **team** —
  never as an individual collaborator, and never **Admin**. An Admin can edit
  branch protection and delete the gate, which makes the whole arrangement
  theatre.

**One-time, create the team:**

1. Org → Teams → New team, name it `developers`.
2. Repo → Settings → Collaborators and teams → Add team → `developers` →
   **Write**.

**For each new developer:**

1. Org → People → Invite member. Role: **Member**.
2. Add them to the `developers` team. That is what grants repo access — do not
   add them to the repo directly, or you end up managing permissions in two
   places.
3. Point them at `CONTRIBUTING.md`. The only setup they need is
   `scripts/bootstrap.sh`, and the SessionStart hook runs it for them.
4. Have them open a small PR and get it reviewed by someone else. That proves
   the loop works for them end to end before they rely on it.

**Confirm** on their first PR: their commits show their avatar and link to
their account (the SessionStart hook sets git identity from whoever the session
is authenticated as), CI runs, the preview deploys, and the PR cannot merge
until another person approves it.
