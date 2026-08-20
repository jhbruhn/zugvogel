#!/usr/bin/env bash
# Compiles the probe template against zv_report_common.typ and asserts on the
# text that comes out.
#
# A zero exit code from `typst compile` is not enough: a `set` rule in a
# function that does not take its body compiles cleanly and styles nothing, and
# a footer that silently fails to render looks exactly like one that was never
# asked for. So this checks the strings.
#
# Needs `typst` on PATH (the zugvogel-pb-base image carries it).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

typst compile --root "$here/.." "$here/probe.typ" "$out/probe.pdf"

text="$(pdftotext "$out/probe.pdf" - 2>/dev/null)"

fail=0
expect() {
  if ! grep -qF -- "$1" <<<"$text"; then
    echo "MISSING: $1" >&2
    fail=1
  fi
}

# The app's own strings resolve.
expect "Probebericht"
# A shared_strings.json entry resolves the same way as an inline one — the whole
# point of the two-file mechanism.
expect "In Pflege"
expect "Datum"
# An enum value this build does not know falls back to the WIRE value rather
# than to a guess or to nothing.
expect "brandnew"
# Dates come from PARTS, in the caller's calendar.
expect "20.08.2026"
expect "23:45"
# Joins drop the empties instead of leaving a dangling separator.
expect "a — b"
expect "x · y"
expect "2.5 mg/kg"
# The footer, which only renders if a4Report was applied as a show rule.
expect "2026-014"
expect "Erstellt am"
expect "Seite 1 von 1"

if [ "$fail" -ne 0 ]; then
  echo "typst report base: FAILED" >&2
  exit 1
fi
echo "typst report base: ok"
