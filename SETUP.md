# One-time repo setup

Everything here needs org-owner or repo-admin rights, so it cannot be done by
an agent session. Work top to bottom; each step says how to confirm it worked.

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
the per-PR preview builds depend on Pages. Confirm that before step 5.

## 2. Install the Claude GitHub App

From a Claude Code terminal session, run `/install-github-app`, or install it
manually from https://github.com/apps/claude.

Grant it access to `Great-Grand-Software/blueberry`.
You must be a repo admin.

**Confirm:** the app appears under Settings → GitHub Apps for the repo.

## 3. Add the `ANTHROPIC_API_KEY` secret

Settings → Secrets and variables → Actions → New repository secret.

- Name: `ANTHROPIC_API_KEY`
- Value: a key from an **Anthropic Console account with API billing**, kept
  separate from any Claude subscription used for interactive coding sessions.

**Confirm:** open any PR. The `claude-review` job fails immediately with a
clear error if the secret is missing, so a silent misconfiguration is not
possible.

## 4. Apply branch protection and merge policy

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

This sets: PRs required on `main`; the five CI checks required; 1 approving
review; CODEOWNERS binding; squash-only merges; auto-merge on; auto-delete
branch on merge; no force pushes.

**Confirm:** `verify` exits 0 and prints all `PASS`.

## 4a. Godot-on-Pages is proven, not assumed

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

Build size is ~39 MB, nearly all `index.wasm` — well inside GitHub's 100 MB
file limit and the 1 GB Pages limit, but a slow first load on mobile data.
Pages serves it compressed.

## 5. Enable GitHub Pages

Pages needs the `gh-pages` branch to exist, and that branch is created by the
first successful PR preview deployment. So:

1. Open the first PR and let CI finish.
2. Re-run `./scripts/apply-repo-settings.sh apply` to point Pages at
   `gh-pages`, or set it by hand under Settings → Pages → Source: *Deploy from
   a branch* → `gh-pages` / `/ (root)`.

**Confirm:** the preview URL posted on the PR actually loads and plays.

## 6. Know what merges by itself

`.github/workflows/auto-merge.yml` switches GitHub's native auto-merge on for
every non-draft PR. A PR therefore merges itself, squashed, as soon as the five
required checks pass and its required approving review lands — nothing bypasses
branch protection, GitHub does the merging only when every rule is satisfied.

To hold a PR back: open it as a draft, or click auto-merge off on the PR.
To turn the behavior off entirely, delete that workflow.

## 7. Org permissions

- Talon: sole **Org Owner**.
- Everyone else: **Org Member** with repo-level **Write** access — full
  read/write on code, no Admin or Owner rights.

Set under the org's People page and the repo's Settings → Collaborators and
teams.

---

## Known risk to verify on the first real PR

**Does the Claude bot's approval actually satisfy the "1 required approving
review" rule?**

GitHub does not count approvals from every bot identity toward required
reviews. Whether an app-authored approval counts depends on the app's
permissions on the repo. This has **not** been verified end-to-end.

Watch the first PR: if it collects the bot's approval but the merge button
still says "waiting on required review", the fallback options are, in order of
preference:

1. Keep the review requirement and have Talon approve ordinary PRs too
   (safest, adds a human gate).
2. Drop `required_approving_review_count` to `0` while keeping
   `require_code_owner_reviews: true`, so the five CI checks plus CODEOWNERS
   remain the real gates and the bot review stays advisory.
3. Give the reviewing identity a PAT belonging to a machine user with write
   access, so its approvals count.

Option 2 is a one-line change in `scripts/apply-repo-settings.sh`.
