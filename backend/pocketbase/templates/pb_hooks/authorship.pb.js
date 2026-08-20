/// <reference path="../pb_data/types.d.ts" />

// TEMPLATE — copy into the app's pb_hooks/ and fill in ACTOR_FIELDS.
//
// The server states who did the thing. Read the guidance in zv_authorship.js
// before adding an entry: only fields that record an ACTOR belong here, never a
// field naming a person the caller is entitled to assign.
//
// The map lives in the app because a tag list has to be spelled out at
// registration time, and because getting its boundary wrong is consequential in
// both directions — too permissive lets a client forge a signature, too strict
// breaks assignment entirely.

/** collection name → the relation field naming the actor behind the record. */
const ACTOR_FIELDS = {
  // journal_entries: "author",
  // weights: "author",
};

const COLLECTIONS = Object.keys(ACTOR_FIELDS);

onRecordCreateRequest(
  (e) => require(`${__hooks}/zv_guards.js`).authorship(e, ACTOR_FIELDS, true),
  ...COLLECTIONS,
);

// Authorship is written once. An update that names someone else is silently put
// back rather than rejected: the app never sends these fields in a PATCH body at
// all, so anything arriving here is either a client echoing the value it already
// has (a no-op) or an attempt to rewrite history.
onRecordUpdateRequest(
  (e) => require(`${__hooks}/zv_guards.js`).authorship(e, ACTOR_FIELDS, false),
  ...COLLECTIONS,
);
