/// <reference path="../pb_data/types.d.ts" />

// TEMPLATE — copy into the app's pb_hooks/ and fill in the roles.
//
// Provision self-registered OAuth2 users. zv_oauth2_provisioning.js holds the
// role model, the first-user bootstrap and its concurrency resolution, and why
// an unverified email claim must not be trusted.
//
// WHICH roles exist is the app's, and the order of groupMap matters: first match
// wins, so the most privileged group belongs first.

onRecordAuthWithOAuth2Request((e) =>
  require(`${__hooks}/zv_oauth2_provisioning.js`).provision(e, {
    envPrefix: "PREFIX",
    // The id the app's own seed migration wrote.
    defaultOrgId: "org00000default",
    roles: {
      walledOff: "guest",
      bootstrap: "supervisor",
      groupMap: [
        { env: "OIDC_SUPERVISOR_GROUP", role: "supervisor" },
        { env: "OIDC_COORDINATOR_GROUP", role: "coordinator" },
        { env: "OIDC_CARER_GROUP", role: "carer" },
      ],
    },
    audit: require(`${__hooks}/zv_audit.js`).withRegistry(
      require(`${__hooks}/app_audit_registry.js`),
    ),
  }),
);
