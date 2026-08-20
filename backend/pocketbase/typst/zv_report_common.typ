// federfall-i0wq.1 — the shared half of a Zugvogel report template.
//
// What a template imports from here: the string-resolution mechanism, the value
// formatters, and the page furniture. What it does NOT get is any vocabulary —
// the strings dictionary is the app's, because a report's headings are its
// product's words.
//
// ── The two-file strings mechanism ──────────────────────────────────────────
//
// A report has TWO consumers of the same strings, and only one of them is a
// Typst template. The PDF is rendered here; a CSV export of the same data is
// written by a hook, which has no template to translate in. If each kept its
// own copy, a renamed status would come out one way in the PDF and the other
// in the CSV of the same export — and nobody would notice until somebody
// compared them.
//
// So the subset BOTH need — the enum label maps, the table column titles —
// lives in a JSON file that the hook reads with `$os.readFile` and this file
// merges into the Typst dictionary. Call sites then read `S.caseStatus`
// exactly as if it had been declared inline, which is the point: the split is
// invisible to them and cannot be got wrong by forgetting it.
//
// Everything that is a Typst CLOSURE — a pluralising count, an "every N hours"
// phrase — necessarily stays in the app's own `.typ`, since JSON cannot hold a
// function.
//
// Usage, from an app's `report.typ`:
//
//   #import "zv_report_common.typ": resolveStrings, lbl, fmtDate, reportFooter
//   #let SHARED = json("shared_strings.json")
//   #let STRINGS = (de: (title: "Bericht", ...), en: (...))
//   #let S = resolveStrings(STRINGS, SHARED, data.at("lang", default: "de"))

// ── Strings ─────────────────────────────────────────────────────────────────

/// The merged dictionary for [lang], falling back to [fallback] on both halves.
///
/// The app's own [strings] win over [shared] on a key collision, so a template
/// can override a shared label without editing the JSON both consumers read.
#let resolveStrings(strings, shared, lang, fallback: "de") = (
  shared.at(lang, default: shared.at(fallback, default: (:)))
    + strings.at(lang, default: strings.at(fallback, default: (:)))
)

/// Resolves a stable wire value through a strings map.
///
/// Falls back to the WIRE VALUE itself when this build does not know it — the
/// same stance the app's enum readers take. A report that prints `in_care` is
/// ugly; one that prints a guess, or nothing, is wrong.
#let lbl(map, wire) = if wire == none { none } else { map.at(wire, default: wire) }

// ── Joining ─────────────────────────────────────────────────────────────────
//
// Both drop empties first, so a missing middle part never leaves a dangling
// separator — the failure that makes a generated document look broken rather
// than incomplete.

#let joinDash(parts) = parts.filter(p => p != none and p != "").join(" — ")
#let joinDot(parts) = parts.filter(p => p != none and p != "").join(" · ")

// ── Dates ───────────────────────────────────────────────────────────────────
//
// A date arrives as PARTS (`{y, mo, d, h, mi}`), not as a string, because the
// hook already resolved it into the caller's local calendar — see zv_time.js.
// Handing Typst an instant and a format would render the UTC day, which near
// midnight is the wrong one.

#let fmtDate(S, d) = if d == none {
  none
} else {
  datetime(year: d.y, month: d.mo, day: d.d, hour: 0, minute: 0, second: 0)
    .display(S.dateFmt)
}

#let fmtDateTime(S, d) = if d == none {
  none
} else {
  datetime(
    year: d.y,
    month: d.mo,
    day: d.d,
    hour: d.at("h", default: 0),
    minute: d.at("mi", default: 0),
    second: 0,
  ).display(S.dateTimeFmt)
}

/// A quantity with its unit, or none. The unit is DB-authored text and passes
/// through untranslated, like every other label a user typed.
#let quantity(value, unit) = if value == none {
  none
} else {
  str(value) + (if unit != none and unit != "" { " " + unit } else { "" })
}

// ── Page furniture ──────────────────────────────────────────────────────────

/// The footer every A4 report carries: a reference on the left, when it was
/// generated in the middle, and "page x of y" on the right.
///
/// [reference] is whatever identifies this document to the person holding it —
/// a case number, a clutch id. Passed in rather than read from the data,
/// because only the template knows what that is.
#let reportFooter(S, reference, generatedAt) = context [
  #set text(size: 8pt, fill: gray)
  #line(length: 100%, stroke: 0.5pt + gray)
  #v(4pt)
  #reference #h(1fr)
  #S.generatedAtLabel #fmtDate(S, generatedAt) #h(1fr)
  #S.pageLabel #context counter(page).display(
    "1 " + S.pageOfSep + " 1",
    both: true,
  )
]

/// The A4 page setup shared by every report: margins, the footer above, and a
/// serif face at a size that survives being printed and photocopied.
///
/// Takes [body] and is applied as a document show rule, which is not a
/// stylistic choice: a `set` rule inside a plain function body applies only
/// within that block, so a version that did not take the body would compile
/// cleanly and style nothing at all.
///
///   #show: doc => a4Report(S, data.case.caseNumber, data.generatedAt, doc)
#let a4Report(S, reference, generatedAt, body) = {
  set page(
    paper: "a4",
    margin: (x: 2cm, y: 2cm),
    footer: reportFooter(S, reference, generatedAt),
  )
  set text(font: "Libertinus Serif", size: 10.5pt)
  set heading(numbering: none)
  body
}
