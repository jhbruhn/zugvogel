/// <reference path="../pb_data/types.d.ts" />

// TEMPLATE — copy into the app's pb_hooks/ and replace PREFIX.
//
// Security headers for the SPA and for uploaded files. zv_web_headers.js holds
// the policy and the reasoning — including why the CSP is load-bearing for the
// web build's token storage and not merely defence in depth.

routerUse((e) =>
  require(`${__hooks}/zv_web_headers.js`).apply(e, { envPrefix: "PREFIX" }),
);
