const test = require("node:test");
const assert = require("node:assert/strict");
const { install, hook } = require("./globals.js");

const env = install();
const org = hook("zv_org.js");
const orgScope = hook("zv_org_scope.js");
const time = hook("zv_time.js");
const geocode = hook("zv_geocode.js");
const authorship = hook("zv_authorship.js");

// ── zv_org: the JSONRaw trap (federfall-jumi) ───────────────────────────────

test("settingsOf parses the JSON TEXT, not the raw byte array", () => {
  // The whole reason this module exists. record.get(<json field>) hands JS a
  // types.JSONRaw — a byte array — so `settings.someKey` is ALWAYS undefined
  // and a caller silently falls through to its default. getString() returns the
  // raw JSON text, which parses. federfall had two shipped features silently
  // inert for every org because of this.
  const app = {
    findRecordById: () => ({
      getString: (f) => (f === "settings" ? '{"retentionYears":3}' : ""),
      // What a caller must NOT use, modelled so the test is about the choice.
      get: () => [123, 34, 114],
    }),
  };
  assert.deepEqual(org.settingsOf(app, "org1"), { retentionYears: 3 });
});

test("settingsOf answers {} rather than throwing, for every failure", () => {
  // A throwing reader would turn a blank field into a failed write or a dead
  // cron; every caller's answer to "no settings" is its own documented default.
  const missing = {
    findRecordById: () => {
      throw new Error("no such org");
    },
  };
  assert.deepEqual(org.settingsOf(missing, "org1"), {});
  assert.deepEqual(org.settingsOf(missing, ""), {});

  const garbage = {
    findRecordById: () => ({ getString: () => "not json" }),
  };
  assert.deepEqual(org.settingsOf(garbage, "org1"), {});

  const scalar = {
    findRecordById: () => ({ getString: () => "42" }),
  };
  assert.deepEqual(org.settingsOf(scalar, "org1"), {});

  const empty = {
    findRecordById: () => ({ getString: () => "" }),
  };
  assert.deepEqual(org.settingsOf(empty, "org1"), {});
});

test("positiveNumber refuses zero, because a zero window means 'now'", () => {
  // These values are windows — retention years, quarantine days — and a zero
  // window means "expire everything now", which is not something a blank or
  // fat-fingered field should be able to say.
  assert.equal(org.positiveNumber({ days: 0 }, "days", 14), 14);
  assert.equal(org.positiveNumber({ days: -3 }, "days", 14), 14);
  assert.equal(org.positiveNumber({ days: 7 }, "days", 14), 7);
  assert.equal(org.positiveNumber({ days: "7" }, "days", 14), 7);
  assert.equal(org.positiveNumber({ days: "x" }, "days", 14), 14);
  assert.equal(org.positiveNumber({}, "days", 14), 14);
  assert.equal(org.positiveNumber(null, "days", 14), 14);
  // ...unless the setting genuinely means it, and says so.
  assert.equal(
    org.positiveNumber({ years: 0 }, "years", 3, { allowZero: true }),
    0,
  );
});

test("positiveNumberList rejects a broken ladder WHOLE", () => {
  const FALLBACK = [7, 14, 28];
  const ok = (v) => org.positiveNumberList({ steps: v }, "steps", FALLBACK);

  assert.deepEqual(ok([7, 14, 28]), [7, 14, 28]);
  assert.deepEqual(ok(["7", "14"]), [7, 14], "strings from JSON are numbers");
  assert.deepEqual(ok([5]), [5], "a one-rung ladder is legal — no stretch");

  // Each of these fails SILENTLY without the check, and lands far from here.
  assert.deepEqual(ok([]), FALLBACK, "an empty ladder is not a ladder");
  assert.deepEqual(ok(7), FALLBACK, "a bare number is not a ladder");
  assert.deepEqual(ok("7,14"), FALLBACK, "nor is a string");
  assert.deepEqual(ok([7, "x", 28]), FALLBACK, "one bad rung, whole fallback");
  assert.deepEqual(ok([7, 0, 28]), FALLBACK, "zero days is 'due immediately'");
  assert.deepEqual(ok([7, -14]), FALLBACK);
  // The inverted ladder is the nasty one: nothing errors, but the nest that has
  // been empty longest gets checked MOST often.
  assert.deepEqual(ok([28, 14, 7]), FALLBACK, "descending is an inverted rhythm");
  assert.deepEqual(ok([7, 28, 14]), FALLBACK, "and so is a dip in the middle");
  assert.deepEqual(ok([7, 7, 14]), [7, 7, 14], "a flat rung is not a dip");

  assert.deepEqual(
    org.positiveNumberList({}, "steps", FALLBACK), FALLBACK);
  assert.deepEqual(
    org.positiveNumberList(null, "steps", FALLBACK), FALLBACK);
});

test("flag is true only on an explicit opt-in", () => {
  assert.equal(org.flag({ x: true }, "x"), true);
  assert.equal(org.flag({ x: "true" }, "x"), false);
  assert.equal(org.flag({ x: 1 }, "x"), false);
  assert.equal(org.flag({}, "x"), false);
  assert.equal(org.flag(null, "x"), false);
});

// ── zv_org_scope: ids and schema questions ──────────────────────────────────

test("idsOf handles a single relation, a multi one, and empties", () => {
  assert.deepEqual(orgScope.idsOf("a1"), ["a1"]);
  assert.deepEqual(orgScope.idsOf(["a1", "", "a2"]), ["a1", "a2"]);
  assert.deepEqual(orgScope.idsOf([]), []);
  assert.deepEqual(orgScope.idsOf(""), []);
  assert.deepEqual(orgScope.idsOf(null), []);
  assert.deepEqual(orgScope.idsOf(undefined), []);
});

test("isOrgScoped asks the SCHEMA, not a hand-kept list", () => {
  // A hand-kept list is domain and would have to be copied per app; a schema
  // query is not, which is what makes this check shareable at all.
  const field = (name) => ({ getName: () => name });
  assert.equal(
    orgScope.isOrgScoped({ fields: [field("id"), field("org")] }),
    true,
  );
  assert.equal(orgScope.isOrgScoped({ fields: [field("id")] }), false);
});

// ── zv_time: caller-local dates (federfall-c41f) ────────────────────────────

const query = (params) => ({ get: (k) => (k in params ? params[k] : "") });

test("an explicit offset from the client wins", () => {
  const ctx = time.timeContext(query({ tzOffsetMinutes: "330" }));
  assert.equal(ctx.explicitOffsetMinutes, 330);
  assert.equal(ctx.offsetFor(Date.UTC(2026, 0, 15)), 330);
});

test("an absent or out-of-range offset falls back to the Berlin rule", () => {
  // goja has no Intl and the image carries no tzdata, so a zone NAME cannot be
  // resolved server-side — the client states its offset instead.
  for (const params of [{}, { tzOffsetMinutes: "9999" }, { tzOffsetMinutes: "x" }]) {
    const ctx = time.timeContext(query(params));
    assert.equal(ctx.explicitOffsetMinutes, null);
    // January is CET (+60), July is CEST (+120).
    assert.equal(ctx.offsetFor(Date.UTC(2026, 0, 15)), 60);
    assert.equal(ctx.offsetFor(Date.UTC(2026, 6, 15)), 120);
  }
});

test("the DST switch lands on the EU's own boundary", () => {
  const ctx = time.timeContext(query({}));
  // 2026: last Sunday of March is the 29th, last Sunday of October the 25th.
  assert.equal(ctx.offsetFor(Date.UTC(2026, 2, 29, 0, 59)), 60);
  assert.equal(ctx.offsetFor(Date.UTC(2026, 2, 29, 1, 0)), 120);
  assert.equal(ctx.offsetFor(Date.UTC(2026, 9, 25, 0, 59)), 120);
  assert.equal(ctx.offsetFor(Date.UTC(2026, 9, 25, 1, 0)), 60);
});

test("partsOf gives the CALLER's calendar date, not UTC's", () => {
  // The bug: formatting PocketBase's UTC instant printed 2025-12-31 for a
  // record created at 00:30 on New Year's Day in UTC+2, disagreeing with the
  // very year filter that selected it.
  const ctx = time.timeContext(query({ tzOffsetMinutes: "120" }));
  const parts = ctx.partsOf("2026-01-01 00:30:00.000Z");
  assert.equal(parts.y, 2026);
  assert.equal(parts.mo, 1);
  assert.equal(parts.d, 1);
  assert.equal(parts.h, 2);
  assert.equal(parts.mi, 30);
});

test("partsOf reads PocketBase's space-separated stamp, and rejects junk", () => {
  const ctx = time.timeContext(query({ tzOffsetMinutes: "0" }));
  assert.equal(ctx.partsOf("2026-03-10 09:00:00.000Z").d, 10);
  assert.equal(ctx.partsOf(""), null);
  assert.equal(ctx.partsOf(null), null);
  assert.equal(ctx.partsOf("not-a-date"), null);
});

test("pbStamp round-trips into a filter-comparable string", () => {
  const ctx = time.timeContext(query({}));
  const stamp = ctx.pbStamp(Date.UTC(2026, 2, 10, 9, 0, 0));
  assert.equal(stamp, "2026-03-10 09:00:00.000Z");
  assert.equal(ctx.parseMs(stamp), Date.UTC(2026, 2, 10, 9, 0, 0));
});

// ── zv_geocode: the env prefix and the result shape ─────────────────────────

test("the upstream config reads the app's OWN env prefix", () => {
  // Hardcoding one app's prefix would make the other's deployment silently
  // un-configurable: it would read variables nobody set and fall through to the
  // public Nominatim, which is rate-limited.
  env.clearEnv();
  env.setEnv("EIERMANN_NOMINATIM_URL", "https://geo.example");
  env.setEnv("FEDERFALL_NOMINATIM_URL", "https://wrong.example");

  const eiermann = geocode.withEnv("EIERMANN").upstream();
  assert.equal(eiermann.base, "https://geo.example");
  assert.equal(geocode.withEnv("FEDERFALL").upstream().base, "https://wrong.example");
  // An app with nothing set gets the public default and a UA naming itself.
  const bare = geocode.withEnv("TESTVOGEL").upstream();
  assert.equal(bare.base, "https://nominatim.openstreetmap.org");
  assert.equal(bare.ua, "testvogel/1.0");
  env.clearEnv();
});

test("toResult composes a tidy address, falling back to display_name", () => {
  assert.deepEqual(
    geocode.toResult({
      lat: "53.14",
      lon: "8.21",
      display_name: "long, ugly, upstream, string",
      address: {
        road: "Musterweg",
        house_number: "8",
        postcode: "26125",
        city: "Oldenburg",
        state: "Niedersachsen",
      },
    }),
    {
      lat: 53.14,
      lon: 8.21,
      displayName: "Musterweg 8, 26125 Oldenburg",
      city: "Oldenburg",
      region: "Niedersachsen",
    },
  );

  // Nothing composable → upstream's own string rather than an empty label.
  assert.equal(
    geocode.toResult({ lat: "1", lon: "2", display_name: "Somewhere" })
      .displayName,
    "Somewhere",
  );
});

test("toResult accepts the aliases Nominatim actually sends for a place", () => {
  for (const key of ["city", "town", "village", "municipality", "hamlet"]) {
    const address = {};
    address[key] = "Kleinstadt";
    assert.equal(
      geocode.toResult({ lat: "1", lon: "2", address: address }).city,
      "Kleinstadt",
      key,
    );
  }
});

// ── zv_authorship: the server states who acted ──────────────────────────────

const actorFields = { journal_entries: "author", weights: "author" };

function recordStub(collection, data, original) {
  const store = Object.assign({}, data);
  return {
    collection: () => ({ name: collection }),
    get: (f) => store[f],
    set: (f, v) => {
      store[f] = v;
    },
    original: () => ({ get: (f) => (original || {})[f] }),
    read: (f) => store[f],
  };
}

test("a create is stamped with the authenticated caller, not the body", () => {
  // An actor field is never a choice the client gets to make: it is a statement
  // about who was authenticated, and the server is the only party that knows.
  const record = recordStub("journal_entries", { author: "someone-else" });
  authorship.stampActor(
    { record: record, auth: { id: "u1" } },
    actorFields,
    { isCreate: true },
  );
  assert.equal(record.read("author"), "u1");
});

test("an ordinary edit does NOT reassign authorship", () => {
  // Otherwise saving somebody else's row would silently make it yours.
  const record = recordStub("journal_entries", { author: "u2" }, { author: "u2" });
  authorship.stampActor({ record: record, auth: { id: "u1" } }, actorFields);
  assert.equal(record.read("author"), "u2");
});

test("an edit that TRIES to change the actor is overwritten", () => {
  const record = recordStub("journal_entries", { author: "u9" }, { author: "u2" });
  authorship.stampActor({ record: record, auth: { id: "u1" } }, actorFields);
  assert.equal(record.read("author"), "u1");
});

test("a collection outside the map is left alone", () => {
  // One shared handler, a tag list the app controls.
  const record = recordStub("animals", { author: "kept" });
  authorship.stampActor(
    { record: record, auth: { id: "u1" } },
    actorFields,
    { isCreate: true },
  );
  assert.equal(record.read("author"), "kept");
});

test("no authenticated caller leaves the field to the collection's rules", () => {
  // A hook-driven write has no actor to name; blanking the field would be worse
  // than leaving it.
  const record = recordStub("weights", { author: "u2" });
  authorship.stampActor({ record: record, auth: null }, actorFields, {
    isCreate: true,
  });
  assert.equal(record.read("author"), "u2");
});
