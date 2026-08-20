# Typst report base

`zv_report_common.typ` is the shared half of a report template: the
string-resolution mechanism, the value formatters and the page furniture. The
strings themselves are the app's — a report's headings are its product's words.

`vendor/codetastic` is a pinned copy of the QR-code package, vendored so PDF
generation never depends on the Typst package registry being reachable from
inside the container.

## The two-file strings mechanism

A report usually has two consumers of the same strings, and only one of them is
a template: the PDF is rendered by Typst, while a CSV export of the same data is
written by a hook that has no template to translate in.

Keeping two copies is how a renamed status ends up spelled one way in the PDF
and another in the CSV **of the same export** — a discrepancy nobody notices
until somebody compares them.

So the subset both need lives in a `shared_strings.json` the app ships:

```
typst/
  report.typ            the app's template; owns its STRINGS dict
  shared_strings.json   the enum maps + column titles BOTH consumers read
  zv_report_common.typ  (this library) merges the two
```

The hook reads the JSON with `$os.readFile`; `resolveStrings` merges it into the
Typst dictionary. Call sites then read `S.caseStatus` exactly as if it had been
declared inline — the split is invisible to them, which is what stops it being
got wrong by forgetting it.

Anything that is a Typst **closure** — a pluralising count, an "every N hours"
phrase — necessarily stays in the app's own `.typ`: JSON cannot hold a function.

## What a template still owns

Its `sys.inputs` contract, its layout, its own strings, and every renderer for a
domain shape (which timeline kinds exist, how a dosing rhythm reads). The
payload arrives as a FILE under the typst `--root`, never as an `--input`
string: an argv element is size-capped and world-readable in the process table.

## Testing it

`tests/run.sh` compiles `tests/probe.typ` — a stand-in for an app's template
that exercises every export — and asserts on the rendered **text**.

The text, not the exit code: a `set` rule inside a function that does not take
its body compiles perfectly and styles nothing at all, so a footer that
silently fails to render looks exactly like one that was never asked for. That
is not hypothetical; it is the bug the probe caught while `a4Report` was being
written.

Needs `typst` and `pdftotext` on PATH. Both are in the `zugvogel-pb-base`
image.
