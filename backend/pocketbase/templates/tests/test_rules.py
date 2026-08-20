#!/usr/bin/env python3
"""TEMPLATE — copy into the app's backend/pocketbase/tests/ as its own suite.

Backend rule & hook assertions against a running PocketBase. Driven by run.sh,
which provisions a throwaway instance; standalone otherwise:

    ZV_TEST_URL=http://localhost:8090 ZV_ADMIN_EMAIL=... ZV_ADMIN_PASS=... \
        PYTHONPATH=. python3 test_rules.py

Every assertion is the app's. What comes from zv_harness is the plumbing and the
sweep helpers — and the sweeps are the part worth copying deliberately, because
they are what stops the NEXT collection repeating a mistake.
"""
import sys

from zv_harness import (
    H,
    PNG_1X1,
    fields_of,
    missing_isset_guards,
    rule_grants_via,
    sweep_collections,
)

ORG = "org00000default"

h = H()
T = h.admin_token()


print("[schema sanity]")
cols = h.collections(T)
h.check("the schema lists collections at all", bool(cols), "empty")

# ── Sweeps ─────────────────────────────────────────────────────────────────
#
# Write these FIRST, before the per-collection assertions. A sweep asks the live
# schema a question and answers it for every collection at once, including the
# ones that do not exist yet — which is the only kind of coverage that survives
# somebody adding a collection next month.
#
# A hand-kept list is how federfall shipped one collection without the boundary
# guards its siblings had, and how eleven relation fields went unchecked while a
# hook guarded five. Both were found by a sweep, not by review.

print("\n[sweeps]")

# Every rule that grants access by traversing a parent relation must also pin
# that relation AND `org` with `:isset = false`. A plain field reference in an
# UPDATE rule resolves against the STORED record, so without the pin the grant
# is checked against the OLD parent while a new one is written.
PARENTS = ()  # e.g. ("case", "exam")


def boundary_guards(col):
    rule = col.get("updateRule") or ""
    for parent in PARENTS:
        if not rule_grants_via(rule, parent):
            continue
        missing = missing_isset_guards(rule, [parent, "org"])
        if missing:
            return "no " + "/".join(missing) + " guard"
    return ""


if PARENTS:
    sweep_collections(
        h,
        cols,
        "every update rule granting via a parent pins its boundary relations",
        boundary_guards,
    )


def org_scoped(col):
    """Every client-writable collection carries an `org`, or names its parent.

    Without one there is nothing for the access rules to compare against, and
    zv_org_scope has nothing to check either.
    """
    names = [f.get("name") for f in fields_of(col)]
    if "org" in names:
        return ""
    return "no org field (and no documented parent fallback)"


# sweep_collections(h, cols, "every writable collection is org-scoped", org_scoped)


print("\n[the app's own assertions go here]")
# h.mkuser(T, "carer@example.org", "carer", ORG)
# s, token = h.login("carer@example.org")
# h.check("a carer can sign in", s == 200, f"status {s}")

sys.exit(h.summary())
