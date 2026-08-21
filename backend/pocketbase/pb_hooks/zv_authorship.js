/// <reference path="../pb_data/types.d.ts" />

// federfall-vfry — "who DID the thing" is stated by the server, never by the
// client.
//
// Usage — `require()` INSIDE the handler, `${__hooks}` absolute form:
//
//   const authorship = require(`${__hooks}/zv_authorship.js`);
//   authorship.stampActor(e, ACTOR_FIELDS);
//
// ── What belongs in an app's ACTOR_FIELDS map ───────────────────────────────
// Only fields that record an ACTOR — who wrote this, who gave this dose, who
// performed this release. Those are never a choice the client gets to make:
// they are a statement about who was authenticated, and the server is the only
// party that knows the answer.
//
// Deliberately NOT actor fields, because they name a person who is genuinely
// assignable and the caller is entitled to pick them: the member responsible
// for an enclosure, the current carer of a case, the receiving party of a
// handoff, the colleague being granted access. Getting this line wrong in the
// permissive direction lets a client forge a signature; getting it wrong in the
// strict direction breaks assignment entirely, so the map is the app's to write
// and to test.
//
// The MAP is domain. The stamping is not, which is why only the latter is here.
//
// STATELESS (see zv_audit.js): each pooled JSVM holds its own instance, so
// nothing here may cache a decision between calls.

/**
 * Force [record]'s actor field to the authenticated caller.
 *
 * [actorFields] is `{collection: field}` — the app's map. A collection that is
 * not in it is left alone, so one shared handler can be registered over a tag
 * list the app controls.
 *
 * Overwrites whatever the client sent rather than validating it: a mismatch is
 * not a validation error to report, it is a value with no standing.
 *
 * On CREATE the field is stamped with the caller. On UPDATE the stored value is
 * put BACK — authorship is written once. The distinction matters and this
 * function used to get it wrong: it stamped the caller on update too, so a
 * second person editing a colleague's record and sending a changed actor field
 * became its author. Restoring instead means an edit can never move authorship
 * at all, which is the property the callers actually rely on.
 *
 * Nothing catches that difference by accident, either: a test where the editor
 * IS the original author passes under both behaviours, and that is the natural
 * test to write.
 */
function stampActor(e, actorFields, opts) {
  const record = e.record;
  if (!record) return;
  let collection = "";
  try {
    collection = String(record.collection().name);
  } catch (_) {
    return;
  }
  const field = (actorFields || {})[collection];
  if (!field) return;

  let actorId = "";
  try {
    actorId = e.auth ? String(e.auth.id || "") : "";
  } catch (_) {
    actorId = "";
  }
  // No authenticated caller: leave the field to the collection's own rules
  // rather than blanking it. A hook-driven write has no actor to name.
  if (!actorId) return;

  const isCreate = !!(opts && opts.isCreate);
  if (isCreate) {
    record.set(field, actorId);
    return;
  }

  // Update: put the stored value back if the client tried to change it. Not the
  // caller — that would let whoever edits a record take authorship of it.
  let before = "";
  try {
    before = String(record.original().get(field) || "");
  } catch (_) {
    // No stored record to compare against; nothing to restore, and stamping
    // here would invent an author for a row that had none.
    return;
  }
  if (String(record.get(field) || "") !== before) {
    record.set(field, before);
  }
}

module.exports = {
  stampActor: stampActor,
};
