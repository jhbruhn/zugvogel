#!/usr/bin/env python3
"""Tests for the shared harness itself — no PocketBase needed.

A harness that miscounts, or a sweep helper that matches the wrong thing, makes
every suite built on it lie. The `rule_grants_via` case below is the one that
matters most: a version that counted nested traversals would report every rule
in the schema, and a sweep that cries wolf gets switched off.

    python3 test_zv_harness.py
"""
import struct
import sys
import zlib

from zv_harness import (
    H,
    PNG_1X1,
    base_collections,
    client_writable,
    fields_of,
    missing_isset_guards,
    rule_grants_via,
    sweep_collections,
)

h = H(base="http://127.0.0.1:1")


def case(name, ok, detail=""):
    h.check(name, ok, detail)


print("[reporting]")
probe = H(base="http://127.0.0.1:1")
probe.check("(inner)", True)
probe.check("(inner)", False)
case("check counts both outcomes", probe.passed == 1 and probe.failed == 1)
case("summary exits non-zero on a failure", probe.summary() == 1)
clean = H(base="http://127.0.0.1:1")
clean.check("(inner)", True)
case("summary exits zero when everything passed", clean.summary() == 0)

print("\n[the PNG fixture]")
ok = PNG_1X1[:8] == b"\x89PNG\r\n\x1a\n"
i, crcs = 8, []
while i < len(PNG_1X1):
    ln = struct.unpack(">I", PNG_1X1[i : i + 4])[0]
    typ = PNG_1X1[i + 4 : i + 8]
    data = PNG_1X1[i + 8 : i + 8 + ln]
    crc = struct.unpack(">I", PNG_1X1[i + 8 + ln : i + 12 + ln])[0]
    crcs.append(crc == (zlib.crc32(typ + data) & 0xFFFFFFFF))
    i += 12 + ln
# The whole reason this constant is here rather than in each suite: the fixture
# it replaced had a broken IDAT CRC that only Typst's decoder rejected, so it
# passed every upload test and failed only once a report embedded it.
case("every chunk CRC is correct, so a strict decoder accepts it", ok and all(crcs))

print("\n[sweep helpers]")
case("a top-level traversal is a grant", rule_grants_via("case.org = x", "case"))
case(
    "a NESTED traversal is not a grant via the inner relation",
    not rule_grants_via("exam.case.org = x", "case"),
)
case(
    "...but it is one via the outer",
    rule_grants_via("exam.case.org = x", "exam"),
)
case("a similarly named field is not a match", not rule_grants_via("cases.org", "case"))
case("an empty rule grants nothing", not rule_grants_via("", "case"))
case("a null rule grants nothing", not rule_grants_via(None, "case"))

case(
    "a missing isset guard is reported, a present one is not",
    missing_isset_guards("@request.body.org:isset = false", ["case", "org"]) == ["case"],
)
case(
    "both missing are reported",
    missing_isset_guards("", ["case", "org"]) == ["case", "org"],
)

print("\n[collection filtering]")
cols = [
    {"name": "widgets", "type": "base", "createRule": "", "updateRule": ""},
    {"name": "derived", "type": "base", "createRule": None, "updateRule": None},
    {"name": "summaries", "type": "view", "createRule": None, "updateRule": None},
    {"name": "users", "type": "auth", "createRule": "", "updateRule": ""},
]
case("a hook-only collection is not client-writable", not client_writable(cols[1]))
case("a rule of empty string IS client-writable", client_writable(cols[0]))
case(
    "views and auth collections are out of a base sweep",
    [c["name"] for c in base_collections(cols)] == ["widgets"],
)
case(
    "writable_only=False keeps the hook-only ones",
    [c["name"] for c in base_collections(cols, writable_only=False)]
    == ["widgets", "derived"],
)

case(
    "fields_of filters by kind",
    [f["name"] for f in fields_of(
        {"fields": [
            {"name": "id", "type": "text"},
            {"name": "org", "type": "relation"},
        ]},
        "relation",
    )] == ["org"],
)

print("\n[sweep_collections]")
swept = H(base="http://127.0.0.1:1")
sweep_collections(swept, cols, "everything holds", lambda c: "")
case("a sweep that finds nothing passes", swept.passed == 1)
swept2 = H(base="http://127.0.0.1:1")
sweep_collections(swept2, cols, "nothing holds", lambda c: "nope")
case(
    "a sweep names every offender in ONE failure, not one each",
    swept2.failed == 1 and swept2.passed == 0,
)

print("\n[refusal shapes]")
# The two shapes that make a naive read assertion pass on a public database.
case("ok() accepts 204, which is what a DELETE answers",
     H.ok(204) and H.ok(200) and not H.ok(404) and not H.ok(400))
import inspect
reads = inspect.getsource(H.reads_nothing)
case("reads_nothing checks the ITEMS of a list, not just the status",
     "items" in reads)
case("...and uses the single-record path when given an id",
     "record_id" in reads)


print("\n[hook scope sweep]")
import os
import tempfile

with tempfile.TemporaryDirectory() as tmp:
    with open(os.path.join(tmp, "clean.pb.js"), "w") as handle:
        handle.write('routerAdd("GET", "/x", (e) => {\n  const cfg = {a: 1};\n});\n')
    with open(os.path.join(tmp, "broken.pb.js"), "w") as handle:
        handle.write('const config = () => ({a: 1});\nrouterAdd("GET", "/x", (e) => config());\n')
    with open(os.path.join(tmp, "zv_lib.js"), "w") as handle:
        handle.write("const helper = 1;\nmodule.exports = {helper};\n")
    found = H.hook_scope_offenders(tmp)
    # The canary: the exact shape that broke eiermann's geocode proxy.
    case("a file-level const in a .pb.js is an offender",
         any(f.startswith("broken.pb.js:1") for f in found), str(found))
    case("...and names the binding, so the fix is obvious",
         any("config" in f for f in found), str(found))
    case("a const INSIDE a handler is fine — that is the fix",
         not any(f.startswith("clean.pb.js") for f in found), str(found))
    case("a zv_ module is exempt; file-level IS how a module works",
         not any(f.startswith("zv_lib") for f in found), str(found))


print("\n[the auth rate limit]")
# Not a live call: this pins the CONTRACT that login retries rather than
# surfacing a 429, because a 429 hands back no token and an empty token reads as
# anonymous — and an anonymous LIST returns 200 with zero rows, which is
# indistinguishable from a rule that is too strict.
import inspect
src = inspect.getsource(H.login)
case("login retries instead of returning a 429", "429" in src and "sleep" in src)
case("...a bounded number of times", "attempts" in src)


print("\n[timestamps]")
future = H.stamp(days=2)
past = H.stamp(days=-2)
case("a stamp is PocketBase-shaped", future.endswith("Z") and future[10] == " ")
case("relative to now, in both directions", past < H.stamp() < future)

sys.exit(h.summary())
