// A stand-in for an app's report template, exercising every export of
// zv_report_common.typ.
//
// It exists because a Typst template is not type-checked by anything else: a
// `set` rule in a function that does not take its body compiles cleanly and
// styles NOTHING, which is exactly the bug this probe caught while a4Report was
// being written. The run script asserts on the rendered TEXT, not just on a
// zero exit code, for the same reason.
#import "../zv_report_common.typ": a4Report, fmtDate, fmtDateTime, joinDash, joinDot, lbl, quantity, reportFooter, resolveStrings

#let SHARED = json("shared_strings.json")
#let STRINGS = (
  de: (
    title: "Probebericht",
    generatedAtLabel: "Erstellt am",
    pageLabel: "Seite",
    pageOfSep: "von",
    dateFmt: "[day].[month].[year]",
    dateTimeFmt: "[day].[month].[year], [hour]:[minute]",
  ),
)
#let S = resolveStrings(STRINGS, SHARED, "de")
#let generatedAt = (y: 2026, mo: 8, d: 20, h: 23, mi: 45)

#show: doc => a4Report(S, "2026-014", generatedAt, doc)

= #S.title

Status: #lbl(S.caseStatus, "in_care") / unknown: #lbl(S.caseStatus, "brandnew")

Date: #fmtDate(S, generatedAt) — DateTime: #fmtDateTime(S, generatedAt)

Joined: #joinDash(("a", none, "", "b")) and #joinDot(("x", none, "y"))

Quantity: #quantity(2.5, "mg/kg") / none: #if quantity(none, "mg") == none [ok]

Shared column title: #S.colDate
