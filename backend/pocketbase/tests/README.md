# Backend tests

Three layers, because they need three different things to run:

| What | Needs | Where |
| ---- | ----- | ----- |
| `unit/` | node | The pure functions in `pb_hooks/zv_*.js`. In CI. |
| `zv_harness.py` | nothing | The shared plumbing an app's suite imports. `test_zv_harness.py` tests it; in CI. |
| `../templates/tests/` | docker | Templates for an app's live-PocketBase suite. Not runnable from here — there is no app to test. |

## Why the live suite cannot live here

A rule test needs a running PocketBase with **migrations applied**, and a
migration is a historical fact belonging to one app (see `../README.md`). There
is no zugvogel schema to spin up, so there is nothing here for `run.sh` to
assert against. Each app runs its own, over the shared harness.

## What the harness is for

`H` is one object per run: the base URL, the counters, the request helpers.
federfall kept those in module globals, which works for exactly one suite per
process — an app that wants a second file then either re-reads the env in both
or shares mutable state between them.

The `PNG_1X1` fixture is here for a specific reason. The one it replaced decoded
fine everywhere it was only stored and served, but had a broken IDAT CRC that
Typst's stricter decoder rejected — so it passed every upload test and failed
only once a report actually embedded it. `test_zv_harness.py` verifies the CRCs.

## The sweeps are the point

A sweep asks the **live schema** a question and asserts the answer for every
collection at once, including the ones that do not exist yet.

That is not a stylistic preference. In federfall, a sampled list of collections
is how one shipped without the boundary guards its siblings had, and how eleven
relation fields went unchecked while a hook guarded five. Both were found by a
sweep; neither was found by review.

Write one whenever the property is about a **shape** rather than about a
specific collection:

- every rule that grants via a parent pins that parent and `org`
- every prose column is redacted in the audit log
- every relation whose target carries an `org` is org-scoped

A test per collection cannot express any of those about a collection somebody
adds next month.

## Two ways a cron test passes vacuously

`run_cron.sh` exists because `cronAdd` jobs are invisible to an API-driven
suite: nothing can trigger one, so the only way to observe a job is to make it
**due**. Both traps are worth knowing:

1. **A `sed` that matches nothing.** The real daily schedule stays, the job
   never runs, and the suite passes having asserted nothing. Every rewrite in
   the template is therefore followed by a `grep` that fails the run.
2. **A grace period that makes the effect unobservable.** If a job waits 24 h
   from a server-owned autodate no client can backdate, no test can ever see it
   act. Neutralise it in the *copy*, and have the Python suite read the
   *committed* file and fail if the real grace period has gone missing — so the
   test cannot become the reason it was deleted.
