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

### How each seam is actually shaped

The obvious design — require the app to override a provider — was tried and
withdrawn: making `pbClientConfigProvider` mandatory broke **173 tests across
86 files** in federfall, none of which cared about configuration. A shared
package that makes every existing test rewrite itself does not get adopted.

So each seam is a **settable global with a throwing default**:

```dart
PbClientConfig? defaultPbClientConfig;   // set once in main()
ZugvogelStringsResolver? defaultZugvogelStrings;
```

- An app sets both in `main()`, and in `test/flutter_test_config.dart` — the
  only hook that reaches *every* test in a package, so no test file needs to
  know the seam exists.
- Reading one unset throws `UnimplementedError` with a message naming what to
  set. Silence would give a widget with English fallbacks, and an app would
  ship it.
- `defaultZugvogelStrings` is a **resolver taking a `BuildContext`**, not a
  strings object. A locale change must re-resolve; capturing the strings in a
  `final` pins the app to whatever locale was active at startup.

### The review checklist

For any change under `packages/`:

- [ ] No `import '…l10n…'`, no literal user-facing text. Every string comes
      from the injected `ZugvogelStrings`, reached through
      `ZugvogelStringsScope.of(context)`.
- [ ] No `Colors.*` and no hex literal in a widget. Status colour comes from
      `ZugvogelSemantics`; chart series from `categorical`/`categoricalOther`.
- [ ] No `String.fromEnvironment`, no `bool.fromEnvironment`, no reading an
      app's environment class. Configuration arrives as a parameter or through
      `pbClientConfigProvider`.
- [ ] Every `Provider`/`FutureProvider`/`StreamProvider` has a `name:`.
      Hand-written providers do not get one for free, and without it a riverpod
      error names no provider at all — this is the real cost of the no-codegen
      rule and a sweep test enforces it.
- [ ] A new `DateTime`→text conversion goes through `formatLocalDate`, not
      `DateFormat` or a `MaterialLocalizations` formatter.
- [ ] A new non-ASCII character in any string is covered by the bundled fonts
      (see the font pinning test in `zugvogel_ui`).

All six are also **source sweeps**, run over all four packages by
`packages/zugvogel_ui/test/injection_boundaries_test.dart` and the date sweep
in `zugvogel_ui/lib/src/testing/`. They are sweeps rather than per-widget tests
because the widget that reintroduces the problem does not exist yet.

**Plant a canary in any guard you add.** Write the violation, watch the guard
fail, then delete it. One of these guards "passed" for an afternoon while
proving nothing: the canary had not planted, because `dart format` moved the
argument the sweep was searching for.

## Migrations cannot be shared

A PocketBase migration is a historical fact. Federfall created `organisations`
under `1700000001` in a file that cannot be retroactively replaced, so this
repo ships **no** `pb_migrations`. Shared: hooks, Typst, tests, CI. Templates
only, copied and renumbered per app: migrations.

Shared hooks live in the reserved `zv_*` namespace so an app hook can never
shadow one. See `backend/pocketbase/README.md`.

### Writing a `zv_*.js` library

The JSVM is neither Node nor a browser, and its one structural rule shapes every
file here: **each hook handler runs in its own isolated context.** A `zv_*.js`
file is a module — file-level bindings inside it are correct and normal — but
the *app* hook that uses it must `require()` it **inside** the handler, in the
absolute `${__hooks}` form. An app-side file-level `const` is not in scope in
the handler and throws `ReferenceError` at request time, which PocketBase
reports as a generic 400. `H.hook_scope_offenders()` sweeps for it, because that
failure shape survives review, boots clean, and only breaks when called.

The rest, each learned the hard way:

- `record.get(key)` **throws** for an absent key. Read request bodies through
  `e.requestInfo().body`.
- A JSON field hands JS a `types.JSONRaw` byte array — every property access is
  `undefined` and the caller falls silently into its default. Pass it straight
  through to `e.json`; never read into it.
- A computed view column falls back to type `json`, so `getString()` returns
  `"value"` *with quotes*. Ask the collection for `field.type()`; never sniff
  per value, because a city named `true` also parses as JSON.
- Use `setPassword()`. `record.set("password", …)` silently does nothing.
  `verified` is a protected system field.
- There is **no global `onServe`**, and `onBootstrap` + `e.next()` does not
  guarantee migrations have been applied — on a fresh data directory a
  bootstrap hook can query collections that do not exist yet.
- A view's `viewQuery` is parsed by PocketBase and follows neither a `--`
  comment nor an expression spanning newlines. One line per computed column,
  reasoning in a JS comment above it.
- Split machinery from app vocabulary with a registry
  (`zv_audit.js`'s `withRegistry(registry)`), so a shared library never names a
  domain concept belonging to one app.

### The Python test harness

`backend/pocketbase/tests/zv_harness.py` is vendored into each app, and three of
its helpers exist because the naive spelling passes against a broken server:

- `h.login()` — the factory rate-limits `*:auth` to **2 requests per 3
  seconds**. Over it, a login returns no token; an empty token reads as
  *anonymous*; and an anonymous LIST returns 200 with zero rows, which is
  indistinguishable from a working rule. It backs off on 429. Never hand-roll a
  login.
- `h.reads_nothing(collection, …)` — a LIST is **filtered, not refused**, so
  `status >= 400` passes against a fully public database.
- `h.ok(status)` — a DELETE answers **204**. `status == 200` fails against a
  working server, which is worse than no test.

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

Flutter 3.44.3 / Dart 3.12, in lockstep with both consuming apps. The pubspecs
require `^3.44.0`, which is what stops a pin bump from dragging an app onto
3.47 — see the section below for what 3.47 does.

### Do not ship on Flutter 3.47.x

3.47 silently loses images on **Firefox and Safari, iPhone included**: a
thumbnail paints once and then draws nothing on any later repaint, until a full
page reload. `CachedFileImage` is the widget it surfaces through, so both apps
inherit it, but nothing in this repo is at fault and no change here fixes it.

Chrome hides the bug, which is why it survives casual testing. `--wasm` ships
skwasm plus a CanvasKit fallback, and flutter.js's default `wasmAllowList` is
`{blink: true, gecko: false, webkit: false}` — so Chrome alone runs skwasm,
which copies decoded bytes eagerly into an `ImageBitmap` it owns. Every other
browser falls back to CanvasKit, where an image decoded from bytes is a **lazy**
SkImage over the `<img>` element the codec created, re-uploading its texture on
every paint. flutter/flutter#186032 then taught the engine to reclaim that
element aggressively: `ImageElementImageSource._doClose()` went from a
deliberate no-op ("let the browser garbage collect it") to
`imageElement.src = ''`. That PR's stated purpose was to stop iOS Safari
crashing on many large images, so the regression lands in the exact case it was
written for.

Established by A/B, not by reading the source: one commit, built
`--wasm --release` against one backend and served with identical COOP/COEP
headers, breaks on 3.47.1 and works on 3.44.3. Three app-side workarounds were
tried and all three failed — clamping the decode below the server thumb,
raising the `ImageCache` ceilings, and waiting out the new 30s decode timeout.
Setting `wasmAllowList: {gecko: true}` does move Firefox onto skwasm and does
fix it there, but `webkit` cannot follow (older iOS has no WasmGC at all), so
it is not a fix for anyone who ships to iPhones.

**3.48 fixes it.** flutter/flutter#188573 moves image decoding and lifetime onto
the shared frontend skwasm already used, and 3.48.0-0.2.pre renders correctly on
the same harness. It is a refactor rather than a targeted fix, so do not wait
for a 3.47.2 backport. Go 3.44.3 → 3.48 and skip 3.47 entirely.

That trap used to sit in *this* repo and is now closed: the pubspecs required
`^3.47.0` while both apps went back to 3.44.3, so their existing pins resolved
only because they predated the bump — and the next pin bump would have failed
their builds. They require `^3.44.0` again, which is what makes a pin bump safe
while 3.47 is being skipped. The Dart packages and the PocketBase image are
separately pinned (see the two-pin table in each app); this is the one that
bites.

When 3.48 lands, all three move together: this repo's pubspecs and CI, then each
app's pin, CI, Dockerfile and onboarding line.


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

## Commits and releases

Conventional commits — release-please derives the version and CHANGELOG from
them. Commit directly on `main`; no feature branches. Push only when asked.

**Never merge the release PR.** release-please keeps one standing, and it is
useful exactly as it is: a rolling summary of what has landed. Merging it would
cut a release, and this repo deliberately has none — both apps pin a commit
hash, and a tag can be re-pointed while pub caches by ref, so two machines would
resolve the same declaration onto different code.

`pubspec.lock` is **not committed** (it is gitignored). A library pins nothing
for its consumers; the apps' own lockfiles decide.
