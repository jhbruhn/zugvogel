# Hook unit tests

`node --test` over the pure functions in `pb_hooks/zv_*.js` — the parts that
need no PocketBase at all: value normalisation, the audit diff and its
redaction, the geocode result shape, caller-local time, relation id parsing.

They run in about a second, so they are the first thing to run after touching a
hook. What they deliberately do NOT cover is anything that touches `app`,
`$app`, a collection or a schema: access rules, cron jobs and hook wiring need a
LIVE PocketBase, which is what the harness beside them is for. Guessing at a
`app.findRecordById` stub would only test the stub.

`globals.js` provides the handful of globals PocketBase injects into a JSVM
(`$os`, `$security`, `require` with the `${__hooks}` form). It stubs only what
these functions actually reach for; anything more would be pretending.
