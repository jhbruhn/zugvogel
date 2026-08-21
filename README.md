# Zugvogel

The shared library behind federfall and eiermann: the part of both apps that carries no product vocabulary. Four Dart packages plus
the PocketBase and Typst assets that go with them.

Zugvogel is not an app and is not published to pub.dev. Both apps consume it
through a **pinned git ref**, so neither one moves until it is moved
deliberately.

## Layout

```
packages/
  zugvogel_core/       pure Dart — GeoPoint, converters, wire-value enums,
                       Result, ErrorMessage, logger
  zugvogel_data/       pure Dart — generic PocketBase repository, PbFilter,
                       keyset paging, multipart, idempotency
  zugvogel_pb_client/  Flutter — client, auth token, server URL, reachability
                       probe, /info, version compatibility, realtime
  zugvogel_ui/         Flutter — widgets, charts, map layers, bundled fonts
backend/pocketbase/
  pb_hooks/            shared hooks in the reserved zv_* namespace
  typst/               report_common.typ and the vendored Typst packages
  tests/               the rule/hook harness templates
```

Dependency direction is one-way: `ui`/`pb_client` → `data` → `core`. Nothing
depends upwards, and nothing in this repo depends on either app.

## Consuming it

Pin a **commit hash**, never a branch and never a tag:

```yaml
dependencies:
  zugvogel_ui:
    git:
      url: https://github.com/jhbruhn/zugvogel.git
      ref: 0000000000000000000000000000000000000000  # a full 40-char SHA
      path: packages/zugvogel_ui
```

A commit hash is the only ref that cannot move. A branch obviously moves; a tag
can be re-pointed, and `pub` caches by ref, so a moved tag means two machines
resolve the same declaration to different code and only one of them can
reproduce the bug. Nothing here is released — there are no tags at all — so the
hash is also the only ref there is.

Use the full 40 characters. `pub` accepts a short one, but a short hash is
ambiguous in principle and unhelpful in practice: it cannot be pasted into a
compare URL, and `git log <short>..<short>` is exactly what you want when a
version bump breaks something.

The **https** URL, not `git@github.com:` — a CI runner has no SSH key, and a
dependency that only resolves on a developer's laptop is a dependency that
breaks the build. The repo is public, so https needs no credentials at all. Push
over SSH (`git@github.com:jhbruhn/zugvogel.git`); that is the remote configured
here.

The members declare `resolution: workspace` for local development, which does
**not** stand in the way of git consumption — verified: a consuming app that
pins `zugvogel_data` and `zugvogel_ui` resolves their relative path
dependencies inside the same checkout and ends up with exactly one copy of
`zugvogel_core`.

`pubspec.lock` is deliberately not committed here. This repo ships libraries;
the consuming app's lockfile is the one that pins versions.

## Versioning

**Nothing is released yet, on purpose.** Both apps pin a commit hash (see
above), so a version number would be decoration — and a tag that exists is a
tag somebody can pin by accident.

The machinery is in place for when that changes: release-please watches
conventional-commit history and maintains a standing release PR with the next
bump and a CHANGELOG. Merging that PR is what would cut a release; leaving it
open costs nothing and creates nothing. Pre-1.0 the config bumps a *minor* for a
breaking change and a *patch* for a feature.

There is no `bootstrap-sha` in `release-please-config.json`: the repo starts
here, so reading the full history is correct.

## The rules

Three injection boundaries keep a wide shared package from welding two product
designs together — no strings, no colours, no configuration inside the
package. And PocketBase **migrations cannot be shared**, only copied as
templates. Both are spelled out in `CLAUDE.md`.

## Toolchain

Flutter 3.47.1 / Dart 3.13. This library is compiled by the consuming apps'
toolchain, so the version in `.github/workflows/ci.yml` must stay in lockstep
with theirs.

## Licence

AGPL-3.0, same as the apps that consume it. See `LICENSE`.
