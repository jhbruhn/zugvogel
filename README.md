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

Pin a tag, never a branch:

```yaml
dependencies:
  zugvogel_ui:
    git:
      url: https://github.com/<owner>/zugvogel.git
      ref: v0.1.0
      path: packages/zugvogel_ui
```

The members declare `resolution: workspace` for local development, which does
**not** stand in the way of git consumption — verified: a consuming app that
pins `zugvogel_data` and `zugvogel_ui` resolves their relative path
dependencies inside the same checkout and ends up with exactly one copy of
`zugvogel_core`.

`pubspec.lock` is deliberately not committed here. This repo ships libraries;
the consuming app's lockfile is the one that pins versions.

## Versioning

One version for the whole repo, on every package, bumped by release-please
from conventional commits. Merging its release PR tags `vX.Y.Z` — that tag is
the artefact both apps pin. Pre-1.0 the config bumps a *minor* for a breaking
change and a *patch* for a feature.

There is no `bootstrap-sha` in `release-please-config.json`: the repo starts
here, so reading the full history is correct.

## The rules

Three injection boundaries keep a wide shared package from welding two product
designs together — no strings, no colours, no configuration inside the
package. And PocketBase **migrations cannot be shared**, only copied as
templates. Both are spelled out in `CLAUDE.md`.

## Toolchain

Flutter 3.44.3 / Dart 3.12. This library is compiled by the consuming apps'
toolchain, so the version in `.github/workflows/ci.yml` must stay in lockstep
with theirs.

## Licence

AGPL-3.0, same as the apps that consume it. See `LICENSE`.
