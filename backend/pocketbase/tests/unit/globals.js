// The globals PocketBase injects into a hook's JSVM, stubbed just far enough
// for the pure functions to run under `node --test`.
//
// Deliberately minimal. A stub of `app` or `$app` would let a test assert
// against a fiction — those paths belong to the live harness next door.

const path = require("node:path");

const hooksDir = path.join(__dirname, "..", "..", "pb_hooks");

/** Installs the globals and returns a handle for adjusting the fake env. */
function install(env) {
  const environment = Object.assign({}, env || {});

  globalThis.__hooks = hooksDir;
  globalThis.$os = {
    getenv: (name) => environment[name] || "",
  };
  globalThis.$security = {
    // Deterministic, so a test can assert on a request id at all. The real one
    // is random; nothing here depends on which.
    randomString: (n) => "r".repeat(n),
  };
  globalThis.$app = {
    logger: () => ({
      warn: () => {},
      info: () => {},
      error: () => {},
    }),
  };

  return {
    setEnv: (name, value) => {
      environment[name] = value;
    },
    clearEnv: () => {
      for (const key of Object.keys(environment)) delete environment[key];
    },
  };
}

/** Loads a hook module the way a handler does, after [install]. */
function hook(name) {
  return require(path.join(hooksDir, name));
}

module.exports = { install: install, hook: hook, hooksDir: hooksDir };
