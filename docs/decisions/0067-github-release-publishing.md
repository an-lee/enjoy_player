# ADR-0067: GitHub Release publishing for cross-platform release workflows

## Status

Proposed

## Context

`release_android.yml`, `release_apple.yml`, `release_linux.yml`, and
`release_windows.yml` already build, sign, and ship platform binaries
(Play Store + TestFlight + notarized macOS zip + direct-download S3
feeds on `dl.enjoy.bot`). There is no first-class **GitHub Release**,
so artifacts are only retrievable from the per-store or R2 channels.
Maintainers currently keep the `v*` tag + the changelog in sync by
hand, and external users cannot download signed binaries from a single
canonical page on the GitHub repository.

We want a GitHub Release for every shipped tag so that:

- every binary is reachable from a stable URL tied to the version
- the changelog, store URLs, and asset list live in one place
- external mirrors / packaging tools (e.g. `brew`, WinGet, Flathub)
  can read the release API instead of scraping `dl.enjoy.bot`

The four existing release workflows are intentionally split because
each platform requires a different self-hosted runner and a different
secret surface (Apple keychain + notary creds; Android Play SA +
keystore; Windows Sparkle DSA; Linux no signing). A merged "one
workflow to rule them all" is not viable — even with a `matrix` job,
each matrix entry still needs a different `runs-on` label and a
different secret map, and the parallelization and partial-release
semantics we already have (Android ships today, macOS ships tomorrow)
would be lost.

Two further constraints drive the design:

- **Manual and tag-driven triggers.** Maintainers still want to run a
  per-platform release workflow on demand (e.g. retry notarization
  for macOS alone) and to ship hot-fixes for a single platform
  without churning the others. The same workflow must accept both
  `workflow_dispatch` and `push: tags: ['v*.*.*']` without duplicating
  any step.
- **Idempotency.** Platforms ship on independent cadences. If we push
  `v0.7.3` and the Apple run completes first, Android two hours later,
  Windows the next morning, the GitHub Release for `v0.7.3` must end
  up containing **all** uploaded assets — never two releases, never a
  partial release that silently supersedes the older one.

## Decision

### 1. Keep the four per-platform workflows split

`release_android.yml`, `release_apple.yml`, `release_linux.yml`,
`release_windows.yml` remain independent. They each:

- gain `on.push.tags: ['v*.*.*']` alongside the existing `workflow_dispatch`
- escalate `permissions` from `contents: read` to `contents: write`
- end the build job with a single new step that calls
  [`softprops/action-gh-release@v2`](https://github.com/softprops/action-gh-release)
  with `draft: true` and the platform's resolved asset paths

`softprops/action-gh-release@v2` is **idempotent on tag**: it creates
the release if absent and otherwise uploads/replaces the named assets
on the existing release. Combined with `draft: true`, this gives us
the property that any number of partial releases accumulate into a
draft that the maintainer promotes when ready — and any one platform
can retry its upload without disturbing the others.

The upload step is gated by `startsWith(github.ref, 'refs/tags/v')`
so `workflow_dispatch` runs continue to behave as today (no
accidental GitHub Release creation when retrying a notarization).

### 2. One small coordinator for the release body and finalize

A new `release_publish.yml` workflow (manual-only, `workflow_dispatch`)
owns the **single** release body for a tag and the draft→ready
transition. It:

- reads `docs/releases/<version>.md` if present, otherwise falls back
  to `## [Unreleased]` from `CHANGELOG.md`
- calls `gh release edit <tag> --notes-file …` to set the body
- optionally flips `gh release edit <tag> --draft=false` to publish

This keeps "what's in the release notes" out of the per-platform
workflows (where it would duplicate four times) and out of CI logs
(where a multi-line heredoc becomes unreadable).

### 3. Local helper for `--publish-github`

The same upload capability is reachable from a maintainer's laptop
without leaving the existing release scripts:

```bash
bash .github/scripts/release.sh --platform android --publish-only --publish-github
bash .github/scripts/release.sh --platform all --publish-only --publish-github
```

A new `release_publish_github` helper in `release_lib.sh` resolves the
version from `pubspec.yaml`, collects the per-platform artifact paths
via the existing `release_*_path` functions, and shells out to `gh
release` (which the maintainer has already authenticated with `gh
auth login`). In CI the helper is bypassed in favour of
`softprops/action-gh-release@v2` so we keep GitHub's vetted action
path for `GITHUB_TOKEN` flows.

A new top-level `--publish-github` flag is plumbed through:

- `.github/scripts/release.sh` (dispatcher help text)
- `.github/scripts/release_publish.sh` (`--platform all`)
- `release_android.sh`, `release_apple.sh`, `release_linux.sh`,
  `release_windows.sh` (per-platform)

### 4. Draft-by-default

All uploaded releases start as **drafts**. Promotion to ready is an
explicit maintainer action via the `release_publish.yml` workflow or
the GitHub web UI. This is the safety net for the "Android finished,
Apple still running" cadence and for partial failures (a Windows
Sparkle signature error never auto-publishes a half-broken release).

## Consequences

### Positive

- Every shipped tag now has a single canonical GitHub Release with
  signed binaries, the versioned changelog, and store links.
- The four release workflows stay small and platform-isolated; no
  runner is asked to do work outside its native environment.
- Tag-driven releases are zero-touch for the maintainer: push the tag,
  wait for the four draft uploads to accumulate, run
  `release_publish.yml` to finalize.
- Local uploads work the same way CI uploads do — the flag is the
  same flag, the asset list is derived from the same helpers.

### Negative / follow-up

- A new permission (`contents: write`) is granted to the four release
  workflows. The pre-existing `permissions: contents: read` blocks any
  release write; the bump is scoped to those workflows only.
- `softprops/action-gh-release@v2` is pinned by tag (e.g. `@v2`) and
  must be updated alongside other Actions updates. The pinned version
  is referenced by SHA in `.github/dependabot.yml`-style tooling when
  added.
- `CHANGELOG.md` remains the changelog source of truth. A future ADR
  may move the "release notes" view of `CHANGELOG.md` into
  `docs/releases/<version>.md` for the GitHub Release body, but that
  is out of scope for this decision.
- The draft→ready transition is manual. If a maintainer forgets to run
  `release_publish.yml`, the release stays a draft even after all four
  builds succeed. This is the intended safety property, but it must
  be communicated in the runbook.

### Out of scope

- Auto-finalize on `workflow_run` (rejected: would publish partial
  releases when a workflow silently fails).
- Migrating the four workflows into a single `release.yml` with
  `workflow_call` matrix entries (rejected: each matrix entry still
  needs a different `runs-on` label and a different secret surface;
  the wrapper adds no value over what already exists).
- Webhook-based Slack / Discord notifications on release publish
  (separate ADR if requested).