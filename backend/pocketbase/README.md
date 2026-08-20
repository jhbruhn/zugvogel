# PocketBase assets

The non-Dart half of Zugvogel. These directories are shipped inside the
`zugvogel-pb-base` Docker image (eiermann-d2a.19); each app's own Dockerfile
starts `FROM` it, so the library version is visible in the image rather than
hidden in a submodule.

| Directory  | Contents |
| ---------- | -------- |
| `pb_hooks` | Shared hooks, all in the reserved `zv_*` namespace so an app hook can never accidentally shadow one. |
| `typst`    | `report_common.typ` plus the vendored Typst packages, and the `shared_strings` mechanism that keeps a PDF and its CSV from drifting. |
| `tests`    | The rule/hook harness templates. Rule tests need a *live* PocketBase and cannot run in the Flutter suite; cron jobs are invisible to it entirely, hence the separate harness. |

## What is NOT here

`pb_migrations`. A PocketBase migration is a historical fact — federfall
created `organisations` under `1700000001` in a file that cannot be
retroactively replaced. Migrations are copied templates, renumbered per app,
never a shared dependency.

## Namespace

Every file added here is prefixed `zv_`. A shared hook named `audit.pb.js`
sitting in the same `pb_hooks` directory as an app's own `audit.pb.js` is the
failure this rule exists to prevent.

Note that each handler runs in an isolated JSVM: `require()` goes *inside* the
handler, in the absolute `__hooks` form.
