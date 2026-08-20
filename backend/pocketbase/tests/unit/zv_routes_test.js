const test = require("node:test");
const assert = require("node:assert/strict");
const { install, hook } = require("./globals.js");

const env = install();
const webHeaders = hook("zv_web_headers.js");
const rateLimits = hook("zv_rate_limits.js");
const geocodeRoute = hook("zv_geocode_route.js");

// ── zv_web_headers: the CSP derives from the same map URLs ───────────────────

test("originOf reads an origin off a raster TEMPLATE, which is not a URL", () => {
  // {z}/{x}/{y} braces make it unparseable by a URL parser, so the origin is
  // matched off the front instead.
  assert.equal(
    webHeaders.originOf("https://tiles.example/{z}/{x}/{y}.png?key={key}"),
    "https://tiles.example",
  );
  assert.equal(
    webHeaders.originOf("http://localhost:8080/style.json"),
    "http://localhost:8080",
  );
  assert.equal(webHeaders.originOf("  https://a.example  "), "https://a.example");
  assert.equal(webHeaders.originOf("not a url"), "");
  assert.equal(webHeaders.originOf(""), "");
  assert.equal(webHeaders.originOf(null), "");
});

test("a prescribed map source is allowed by the CSP automatically", () => {
  // The pairing that matters: zv_info.js may prescribe a tile server, and the
  // browser must not then block the very tiles the server asked for. Both read
  // the same variables, so no operator has to keep two lists in step.
  env.clearEnv();
  env.setEnv("EIERMANN_MAP_TILE_URL", "https://tiles.example/{z}/{x}/{y}.png");
  const origins = webHeaders.tileOrigins("EIERMANN");
  assert.ok(origins.includes("https://tiles.example"), origins);
  // The two shipped defaults stay allowed — they are the fallback an app uses
  // when the server prescribes nothing.
  assert.ok(origins.includes("https://tile.openstreetmap.org"), origins);
  env.clearEnv();
});

test("an explicit origin list REPLACES the defaults", () => {
  env.clearEnv();
  env.setEnv("EIERMANN_MAP_TILE_ORIGINS", "https://only.example");
  const origins = webHeaders.tileOrigins("EIERMANN");
  assert.equal(origins, "https://only.example");
  env.clearEnv();
});

test("a derived origin is not listed twice", () => {
  env.clearEnv();
  env.setEnv("EIERMANN_MAP_TILE_ORIGINS", "https://tiles.example");
  env.setEnv("EIERMANN_MAP_TILE_URL", "https://tiles.example/{z}/{x}/{y}.png");
  assert.equal(webHeaders.tileOrigins("EIERMANN"), "https://tiles.example");
  env.clearEnv();
});

test("the default policy allows wasm but never eval or inline script", () => {
  const csp = webHeaders.defaultCsp("https://tiles.example");
  assert.ok(csp.includes("script-src 'self' 'wasm-unsafe-eval'"), csp);
  assert.ok(!csp.includes("unsafe-eval;"), csp);
  assert.ok(!csp.includes("script-src 'self' 'unsafe-inline'"), csp);
  // The engine injects its own style elements at runtime — that one is required.
  assert.ok(csp.includes("style-src 'self' 'unsafe-inline'"), csp);
  // Tiles are fetched as images (JS renderer) or via fetch (wasm).
  assert.ok(csp.includes("img-src 'self' blob: data: https://tiles.example"), csp);
  assert.ok(csp.includes("connect-src 'self' blob: https://tiles.example"), csp);
  assert.ok(csp.includes("frame-ancestors 'none'"), csp);
  assert.ok(csp.includes("object-src 'none'"), csp);
});

test("uploaded files get their own lockdown, not the SPA policy", () => {
  // A file that slips past the upload MIME allowlist and is opened inline still
  // cannot run script against the app origin.
  const headers = {};
  const e = {
    request: { url: { path: "/api/files/c/r/p.jpg" } },
    response: { header: () => ({ set: (k, v) => (headers[k] = v) }) },
    next: () => "next",
  };
  webHeaders.apply(e, { envPrefix: "EIERMANN" });
  assert.equal(headers["Content-Security-Policy"], "default-src 'none'; sandbox");
  assert.equal(headers["X-Content-Type-Options"], "nosniff");
  assert.equal(headers["Cross-Origin-Opener-Policy"], undefined);
});

test("the API and admin UI are left untouched", () => {
  // Isolation must never interfere with them.
  for (const path of ["/api/collections/x/records", "/_/"]) {
    const headers = {};
    const e = {
      request: { url: { path: path } },
      response: { header: () => ({ set: (k, v) => (headers[k] = v) }) },
      next: () => "next",
    };
    webHeaders.apply(e, { envPrefix: "EIERMANN" });
    assert.deepEqual(headers, {}, path);
  }
});

test("the SPA gets COOP/COEP, and COEP is credentialless", () => {
  // require-corp would BLOCK cross-origin tiles that send no CORP/CORS header;
  // credentialless still enables crossOriginIsolated and fetches them without
  // credentials, so the public tiles keep loading.
  const headers = {};
  const e = {
    request: { url: { path: "/index.html" } },
    response: { header: () => ({ set: (k, v) => (headers[k] = v) }) },
    next: () => "next",
  };
  webHeaders.apply(e, { envPrefix: "EIERMANN" });
  assert.equal(headers["Cross-Origin-Opener-Policy"], "same-origin");
  assert.equal(headers["Cross-Origin-Embedder-Policy"], "credentialless");
  // strict-origin-when-cross-origin, NOT same-origin: with the Referer stripped
  // entirely, tile requests carried NO identification at all and got 403s from
  // OSM (federfall-txxj).
  assert.equal(
    headers["Referrer-Policy"],
    "strict-origin-when-cross-origin",
  );
  assert.ok(headers["Permissions-Policy"].includes("camera=(self)"));
});

test("an operator can replace or disable the policy", () => {
  env.clearEnv();
  env.setEnv("EIERMANN_CSP", "default-src 'self'");
  const replaced = {};
  const request = (headers) => ({
    request: { url: { path: "/index.html" } },
    response: { header: () => ({ set: (k, v) => (headers[k] = v) }) },
    next: () => "next",
  });
  webHeaders.apply(request(replaced), { envPrefix: "EIERMANN" });
  assert.equal(replaced["Content-Security-Policy"], "default-src 'self'");

  env.setEnv("EIERMANN_CSP", "OFF");
  const off = {};
  webHeaders.apply(request(off), { envPrefix: "EIERMANN" });
  assert.equal(off["Content-Security-Policy"], undefined);
  // The other headers stay — only the CSP is opted out of.
  assert.equal(off["X-Content-Type-Options"], "nosniff");
  env.clearEnv();
});

// ── zv_rate_limits: the label trap ──────────────────────────────────────────

test("a bare path prefix is NOT a reachable label", () => {
  // It loses to PocketBase's factory /api/ prefix rule, which is stored first,
  // so the budget silently does nothing. A federfall route was dead that way.
  assert.equal(rateLimits.labelIsReachable("/api/eiermann/geocode/"), false);
  assert.equal(rateLimits.labelIsReachable("GET /api/eiermann/geocode/"), true);
  // An exact path is matched exactly, so it is fine unqualified.
  assert.equal(rateLimits.labelIsReachable("/api/eiermann/geocode"), true);
});

test("the factory defaults include the brute-force brake", () => {
  // The bug this list exists for: an earlier version built the ruleset from a
  // clean slate and shipped instances with NO throttle on auth-with-password.
  const labels = rateLimits.FACTORY_RULES.map((r) => r.label);
  assert.ok(labels.includes("*:auth"), labels.join(","));
  assert.ok(labels.includes("/api/"), labels.join(","));
});

// ── zv_geocode_route: coordinate validation ─────────────────────────────────

test("a coordinate must be a plain number, not parseFloat-salvageable", () => {
  // `52.5abc` passed parseFloat + isFinite and was relayed upstream verbatim,
  // sharing a cache entry with a different point (federfall-185w).
  assert.equal(geocodeRoute.NUMERIC.test("52.5"), true);
  assert.equal(geocodeRoute.NUMERIC.test("-8"), true);
  assert.equal(geocodeRoute.NUMERIC.test("+8.25"), true);
  assert.equal(geocodeRoute.NUMERIC.test("52.5abc"), false);
  assert.equal(geocodeRoute.NUMERIC.test("abc"), false);
  assert.equal(geocodeRoute.NUMERIC.test(""), false);
  assert.equal(geocodeRoute.NUMERIC.test("1,5"), false);
  // Exponent form is accepted because Dart's double.toString() can emit it.
  assert.equal(geocodeRoute.NUMERIC.test("1.5e-7"), true);
});
