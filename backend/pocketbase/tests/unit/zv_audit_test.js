const test = require("node:test");
const assert = require("node:assert/strict");
const { install, hook } = require("./globals.js");

install();
const zvAudit = hook("zv_audit.js");

// A registry standing in for an app's, small enough to read in one go.
const registry = {
  defaultSeverity: { "user.role_changed": "security" },
  sensitive: {
    finders: ["first_name", "last_name", "phone", "email"],
    users: ["tokenKey"],
  },
  freeText: ["notes", "text"],
  neverLabelled: ["finders"],
  labelFields: { animals: ["name", "species"], cases: ["case_number"] },
  relationTargets: { animal: "animals" },
  correlation: {
    collection: "cases",
    field: "case",
    labelField: "case_number",
    via: { exam_findings: { field: "exam", collection: "exams" } },
  },
};

const audit = zvAudit.withRegistry(registry);

test("normalize unwraps a Go value that marshals to a JSON scalar", () => {
  // types.DateTime is the everyday case: record.get() hands one back for every
  // date field, and stringifying it would store '"2026-06-20 07:30:00.000Z"' —
  // unparseable as a date on the way out.
  const dateLike = { toJSON: () => "2026-06-20 07:30:00.000Z" };
  assert.equal(zvAudit.normalize(dateLike), "2026-06-20 07:30:00.000Z");
});

test("normalize reads an empty list as empty, not as the two chars []", () => {
  // Storing "[]" made a renderer read a first value being chosen as a change
  // FROM something instead of as one being set.
  assert.equal(zvAudit.normalize([]), "");
  assert.equal(zvAudit.normalize(["a"]), '["a"]');
});

test("normalize maps null and undefined to empty", () => {
  assert.equal(zvAudit.normalize(null), "");
  assert.equal(zvAudit.normalize(undefined), "");
  assert.equal(zvAudit.normalize(0), 0);
  assert.equal(zvAudit.normalize(false), false);
});

test("clamp truncates long text and says so", () => {
  const long = "x".repeat(zvAudit.MAX_VALUE_CHARS + 10);
  const result = zvAudit.clamp(long);
  assert.equal(result.value.length, zvAudit.MAX_VALUE_CHARS);
  assert.equal(result.truncated, true);
  assert.equal(zvAudit.clamp("short").truncated, false);
});

test("credentials are withheld on any auth collection, registry or not", () => {
  // Not domain: every PocketBase auth collection has these, and leaving one out
  // is a credential in a table with no delete path.
  for (const field of zvAudit.CREDENTIAL_FIELDS) {
    assert.equal(audit.isWithheld("users", field), true, field);
    assert.equal(audit.isWithheld("_superusers", field), true, field);
  }
  // ...and not on an ordinary collection, where such a field name would be
  // something else entirely.
  assert.equal(audit.isWithheld("animals", "password"), false);
});

test("a member of the public's fields are withheld by collection", () => {
  assert.equal(audit.isWithheld("finders", "phone"), true);
  assert.equal(audit.isWithheld("animals", "phone"), false);
});

test("prose is withheld by FIELD NAME, wherever it appears", () => {
  // A field called `notes` is somebody's prose on every collection.
  assert.equal(audit.isWithheld("animals", "notes"), true);
  assert.equal(audit.isWithheld("journal_entries", "text"), true);
  assert.equal(audit.isWithheld("anything_at_all", "notes"), true);
});

test("diff reports only what moved", () => {
  const changes = audit.diff(
    "animals",
    { name: "Lotte", species: "pigeon" },
    { name: "Berta", species: "pigeon" },
  );
  assert.equal(changes.length, 1);
  assert.deepEqual(changes[0], { field: "name", from: "Lotte", to: "Berta" });
});

test("diff ignores the fields that change on every write", () => {
  const changes = audit.diff(
    "animals",
    { updated: "a", created: "x", name: "Lotte" },
    { updated: "b", created: "x", name: "Lotte" },
  );
  assert.deepEqual(changes, []);
});

test("a withheld field keeps the FACT and drops both values", () => {
  // "Someone changed this finder's phone number" is the useful part, and it is
  // the part that is not personal data.
  const changes = audit.diff(
    "finders",
    { phone: "0176 1234567" },
    { phone: "0176 7654321" },
  );
  assert.deepEqual(changes, [{ field: "phone", redacted: true }]);
});

test("prose edits are redacted too — a DENYLIST diff would leak both", () => {
  // The hole this closes: before the free-text list, an EDIT logged 500
  // characters of the old AND the new prose, so a carer editing a name out of a
  // note left the original in a table nothing can delete from.
  const changes = audit.diff(
    "journal_entries",
    { text: "Frau Müller brachte den Vogel" },
    { text: "Eine Finderin brachte den Vogel" },
  );
  assert.deepEqual(changes, [{ field: "text", redacted: true }]);
});

test("a long value is clamped and marked", () => {
  const changes = audit.diff(
    "animals",
    { species: "a" },
    { species: "b".repeat(zvAudit.MAX_VALUE_CHARS + 1) },
  );
  assert.equal(changes[0].truncated, true);
  assert.equal(changes[0].to.length, zvAudit.MAX_VALUE_CHARS);
});

test("a relation change carries ids when no app is given", () => {
  const changes = audit.diff("cases", { animal: "a1" }, { animal: "a2" });
  assert.deepEqual(changes, [{ field: "animal", from: "a1", to: "a2" }]);
});

test("relationTarget prefers a per-collection override", () => {
  const bound = zvAudit.withRegistry({
    relationTargets: { type: "generic_types" },
    relationFields: { markings: { type: "marking_types" } },
  });
  assert.equal(bound.relationTarget("markings", "type"), "marking_types");
  assert.equal(bound.relationTarget("other", "type"), "generic_types");
  assert.equal(bound.relationTarget("other", "unrelated"), "");
});

test("labelOf refuses to name a collection on neverLabelled", () => {
  // Enforced in the library, not trusted to the call site.
  const app = {
    findRecordById: () => ({ get: () => "Frau Müller" }),
  };
  assert.equal(audit.labelOf(app, "finders", "f1"), "");
  const labelled = {
    findRecordById: () => ({ get: (f) => (f === "name" ? "Lotte" : "") }),
  };
  assert.equal(audit.labelOf(labelled, "animals", "a1"), "Lotte");
});

test("labelOf answers empty when the target is gone", () => {
  // The id stays in the change either way, so a missing label loses nothing.
  const app = {
    findRecordById: () => {
      throw new Error("gone");
    },
  };
  assert.equal(audit.labelOf(app, "animals", "a1"), "");
});

test("labelsOf names a whole multi-relation, in stored order", () => {
  const app = {
    findRecordById: (_, id) => ({
      get: (f) => (f === "name" ? "name-" + id : ""),
    }),
  };
  assert.equal(
    audit.labelsOf(app, "animals", '["a1","a2"]'),
    "name-a1, name-a2",
  );
});

test("labelsOf survives an array clamped mid-flight", () => {
  // A multi-relation's id array can exceed MAX_VALUE_CHARS, and half a JSON
  // array parses as nothing at all.
  const app = { findRecordById: () => ({ get: () => "x" }) };
  assert.equal(audit.labelsOf(app, "animals", '["a1","a'), "");
});

test("labelsOf caps how many ids it names", () => {
  const app = {
    findRecordById: (_, id) => ({ get: () => "n" + id }),
  };
  const ids = [];
  for (let i = 0; i < zvAudit.MAX_LABELLED_IDS + 5; i++) ids.push("i" + i);
  const labels = audit.labelsOf(app, "animals", JSON.stringify(ids));
  assert.equal(labels.split(", ").length, zvAudit.MAX_LABELLED_IDS);
});

test("subjectLabel walks label fields, then quantities, then relations", () => {
  const bound = zvAudit.withRegistry({
    labelFields: { animals: ["name", "species"], weights: [] },
    labelQuantities: { weights: { field: "grams", suffix: " g" } },
    labelRelations: { placements: { animal: "animals" } },
  });
  const record = (name, data) => ({
    collection: () => ({ name: name }),
    get: (f) => data[f],
  });

  // First non-empty label field wins.
  assert.equal(bound.subjectLabel(record("animals", { species: "pigeon" })), "pigeon");
  // A quantity of zero is not a label — an unset number field arrives as 0.
  assert.equal(bound.subjectLabel(record("weights", { grams: 0 })), "");
  assert.equal(bound.subjectLabel(record("weights", { grams: 248 })), "248 g");
});

test("subjectLabel resolves one relation level, never two", () => {
  const bound = zvAudit.withRegistry({
    labelFields: { animals: ["name"] },
    labelRelations: { placements: { animal: "animals" } },
  });
  const app = {
    findRecordById: () => ({ get: (f) => (f === "name" ? "Lotte" : "") }),
  };
  const record = {
    collection: () => ({ name: "placements" }),
    get: (f) => (f === "animal" ? "a1" : ""),
  };
  assert.equal(bound.subjectLabel(record, app), "Lotte");
});

test("refsFor collects only the fields a record actually has", () => {
  const bound = zvAudit.withRegistry({ refFields: ["animal", "aviary"] });
  const record = {
    get: (f) => {
      if (f === "animal") return "a1";
      throw new Error("no such field");
    },
  };
  assert.deepEqual(bound.refsFor(record), { animal: "a1" });
  assert.equal(
    bound.refsFor({
      get: () => "",
    }),
    null,
  );
});

test("requestId is stable within one request and fresh without a store", () => {
  const store = {};
  const e = {
    get: (k) => store[k],
    set: (k, v) => {
      store[k] = v;
    },
  };
  const first = audit.requestId(e);
  assert.equal(audit.requestId(e), first);
  assert.equal(first.length, 15);
  // A cron/model event has no store — it still gets an id.
  assert.equal(audit.requestId(null).length, 15);
});
