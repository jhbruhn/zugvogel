# PocketBase assets

The non-Dart half of Zugvogel. These directories are shipped inside the
`zugvogel-pb-base` Docker image (eiermann-d2a.19); each app's own Dockerfile
starts `FROM` it, so the library version is visible in the image rather than
hidden in a submodule.

| Directory  | Contents |
| ---------- | -------- |
| `pb_hooks` | Shared hook **libraries**, all in the reserved `zv_*` namespace. None is a `*.pb.js`, so PocketBase never auto-loads one — they are reachable only through `require()`. |
| `templates/pb_hooks` | The thin `*.pb.js` wrappers an app copies and fills its service name into. See that directory's README for why they cannot be shipped as hooks. |
| `tests/unit` | `node --test` over the pure functions in the libraries. Fast, no PocketBase. |
| `typst`    | `report_common.typ` plus the vendored Typst packages, and the `shared_strings` mechanism that keeps a PDF and its CSV from drifting. |
| `tests`    | The rule/hook harness templates. Rule tests need a *live* PocketBase and cannot run in the Flutter suite; cron jobs are invisible to it entirely, hence the separate harness. |

## What is NOT here

`pb_migrations`. A PocketBase migration is a historical fact — federfall
created `organisations` under `1700000001` in a file that cannot be
retroactively replaced. Migrations are copied templates, renumbered per app,
never a shared dependency.

## Namespace

Every file added here is prefixed `zv_`. A shared file named `audit.js` sitting
in the same `pb_hooks` directory as an app's own `audit.js` is the failure this
rule exists to prevent — and `require()` resolves by path, so it would fail
silently, picking up whichever file happened to be there.

Note that each handler runs in an isolated JSVM: `require()` goes *inside* the
handler, in the absolute `__hooks` form.
