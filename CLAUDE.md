# Project Instructions for AI Agents

Zugvogel is the shared library behind federfall and eiermann. It is not an app.
Read `README.md` for the layout and the consumption model.

Both apps pin a **commit hash**, not a tag: nothing here is released, and a
hash is the only ref that cannot move. When you land a change both apps need,
the follow-up is to bump that hash in each app — there is no release to cut.

## Issue tracking

Work on Zugvogel is tracked in **eiermann's** beads database, not here — Phase
00 (`eiermann-d2a`) is the epic that creates this repo. Run `bd prime` from the
eiermann checkout. Do not initialise a second beads workspace in this repo.

## The three injection boundaries

A shared UI package this wide will weld two product designs together unless it
is kept ignorant of both. So, inside `packages/`:

1. **No strings.** No widget imports an l10n class. Text arrives through an
   injected `ZugvogelStrings` that each app fills from its own ARB files. A
   widget that knows the word "Abbrechen" by itself is a bug.
2. **No colours.** Widgets read `Theme.of(context).colorScheme` plus the
   `ZugvogelSemantics` theme extension for good/warning/critical. Eiermann's
   palette and federfall's stay independent.
3. **No configuration.** No `AppEnvironment` access, no compile-time defines.
   Whatever the package needs is passed in.

Full write-up, with the review checklist: `eiermann-d2a.21`.

## Migrations cannot be shared

A PocketBase migration is a historical fact. Federfall created `organisations`
under `1700000001` in a file that cannot be retroactively replaced, so this
repo ships **no** `pb_migrations`. Shared: hooks, Typst, tests, CI. Templates
only, copied and renumbered per app: migrations.

Shared hooks live in the reserved `zv_*` namespace so an app hook can never
shadow one. See `backend/pocketbase/README.md`.

## Build & test

```bash
flutter pub get                                   # resolves the whole workspace
dart format --output=none --set-exit-if-changed .
flutter analyze                                   # whole workspace from the root

# Pure Dart:
(cd packages/zugvogel_core && dart test)
(cd packages/zugvogel_data && dart test)
# Flutter:
(cd packages/zugvogel_pb_client && flutter test)
(cd packages/zugvogel_ui && flutter test)
```

Flutter 3.44.3 / Dart 3.12, in lockstep with both consuming apps.

## No code generation, anywhere in this repo

Both apps consume Zugvogel as a **git dependency**, and `build_runner` cannot
run inside a fetched dependency — a consumer has no way to generate code for
its dependencies. So nothing here may depend on codegen:

- **riverpod providers are hand-written** against the non-generated API. In
  riverpod 3 a plain `Provider(...)` is keepAlive by default, which is exactly
  what `@Riverpod(keepAlive: true)` meant; write `Provider.autoDispose(...)`
  for the other kind. `AsyncNotifierProvider<T, S>(T.new)` replaces
  `@Riverpod(keepAlive: true) class X extends _$X`.
- **no `freezed`, no `json_serializable`.** Value classes are hand-written
  (see `GeoPoint`): a const constructor, `==`, `hashCode`, `toString`, and
  `copyWith` only where something calls it.

An app may of course still use codegen for its own domain models. This
restriction is Zugvogel's alone.

## Non-interactive shell commands

**Always use non-interactive flags** with file operations — `cp`, `mv` and `rm`
may be aliased to `-i` and will hang an agent waiting for y/n:

```bash
cp -f source dest
mv -f source dest
rm -f file
rm -rf directory
```

Also: `apt-get -y`, `ssh -o BatchMode=yes`, `scp -o BatchMode=yes`.

## Commits

Conventional commits — release-please derives the version and CHANGELOG from
them. Commit directly on `main`; no feature branches. Push only when asked.
