/// <reference path="../pb_data/types.d.ts" />

// TEMPLATE — copy into the app's pb_hooks/ and fill in the parent fallbacks.
//
// A record's relations must live in its own organisation. All the reasoning is
// in zv_org_scope.js; this file exists only because a hook has to be registered
// from a *.pb.js file.

// Where to look for a record's org when it carries none of its own — a child
// row with an OPTIONAL `org` hanging off a parent that has a required one.
// Without this the check is dodged by simply omitting the field.
//
// Leave the array empty if every writable collection carries its own org.
const PARENT_ORG_FALLBACKS = [
  // { field: "case", collection: "cases" },
];

onRecordCreate((e) =>
  require(`${__hooks}/zv_guards.js`).orgScope(e, true, {
    parentOrgFallbacks: PARENT_ORG_FALLBACKS,
  }),
);

onRecordUpdate((e) =>
  require(`${__hooks}/zv_guards.js`).orgScope(e, false, {
    parentOrgFallbacks: PARENT_ORG_FALLBACKS,
  }),
);
