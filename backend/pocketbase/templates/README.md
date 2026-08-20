# App-side templates

Files an app **copies** into its own `backend/pocketbase/pb_hooks/`, renames
without the `zv_` prefix, and fills its service name into.

They are templates and not shipped hooks for one reason: a `*.pb.js` file in
`pb_hooks/` is auto-loaded by PocketBase, and these have to name the app —
its `/api/<service>/…` route paths, its env prefix, its roles, its collection
tag lists. A shared file cannot; a six-line wrapper can.

The reasoning stays in the `zv_*.js` libraries these call. A wrapper should
never grow logic of its own: if it needs to, that logic belongs in the library
behind a parameter, or it is genuinely domain and belongs in a hook of the
app's own.

This is the same split as `pb_migrations`, which are templates for a harder
reason — see `../README.md`.
