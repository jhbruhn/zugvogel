# Changelog

## [0.2.0](https://github.com/jhbruhn/zugvogel/compare/v0.1.0...v0.2.0) (2026-08-21)


### ⚠ BREAKING CHANGES

* zurück auf Flutter 3.44.3 — 3.47 verliert Bilder außerhalb von Chrome
* **hooks:** on update, stampActor now restores the stored actor rather than stamping the caller.
* **errors:** `RepositoryException.serverMessage` and `serverMessagesAreUserFacing` are gone. A consumer that displayed server prose implements `ServerCodeStrings` and maps codes instead.

### Features

* **core:** extract the domain-free primitives ([3941ff7](https://github.com/jhbruhn/zugvogel/commit/3941ff72f8accfa4c0efe37b754725b8ae60fdc9))
* **data:** extract the generic PocketBase repository layer ([9253dad](https://github.com/jhbruhn/zugvogel/commit/9253dadec680f1e92a25e35301ec2739a87ab935))
* **docker:** publish zugvogel-pb-base to GHCR ([d7ea6d1](https://github.com/jhbruhn/zugvogel/commit/d7ea6d1971c52be3f550e395b5cd5bb3a6f8a06a))
* **errors:** hooks send codes, the client owns the sentence ([7f32169](https://github.com/jhbruhn/zugvogel/commit/7f32169b622042476e536767a9408058dc7cd1d6))
* **hooks:** extract the generic routes and guards ([5d2bc72](https://github.com/jhbruhn/zugvogel/commit/5d2bc72c0e0d6aaae28fdc54475f931cba8d7954))
* **hooks:** extract the shared hook libraries into the zv_* namespace ([6d84ab7](https://github.com/jhbruhn/zugvogel/commit/6d84ab7f5e72b3d979257262fbed5a9a8b433f08))
* **hooks:** positiveNumberList for ladder settings ([c9f03bb](https://github.com/jhbruhn/zugvogel/commit/c9f03bbe11a4acb9e9c04faf48554a3800624b50))
* initialise zugvogel — pub workspace, four packages, CI, release-please ([9fb0a35](https://github.com/jhbruhn/zugvogel/commit/9fb0a35852404e1d469ab93435eb288b00f53b89))
* **pb_client:** extract the PocketBase connection ([9315cba](https://github.com/jhbruhn/zugvogel/commit/9315cba088dc6806dcc021e686ae95241c703287))
* **tests:** extract the rule-suite harness and the run-script templates ([461ffae](https://github.com/jhbruhn/zugvogel/commit/461ffaeca5bb341ced3bcc195ff3ec157a4a557f))
* **tests:** harness helpers for the two refusal shapes that fool a suite ([fe7302b](https://github.com/jhbruhn/zugvogel/commit/fe7302b4a15f79a67f8df03ae02486ed20c4b560))
* **tests:** req() takes request headers ([a8507f2](https://github.com/jhbruhn/zugvogel/commit/a8507f27f5494175b63b7ac95eb746599ec9fd37))
* **tests:** shared assertions both apps run against their own instance ([40a65d2](https://github.com/jhbruhn/zugvogel/commit/40a65d23738b9848e0839e493f2bbfb163814791))
* **tests:** shared assertions for /info ([a628e70](https://github.com/jhbruhn/zugvogel/commit/a628e701b098b939e66d59507ba89e6cc4603a6b))
* **tests:** shared assertions for the geocode routes ([616d2e8](https://github.com/jhbruhn/zugvogel/commit/616d2e83db9c51baefd86a28b0e3fbe70220577a))
* **tests:** shared assertions for the rate-limit merge ([ede308d](https://github.com/jhbruhn/zugvogel/commit/ede308d04c47f3ae2b0e75c25afe2326db2f23c9))
* **tests:** sweep for file-level bindings in PocketBase hooks ([fb3fb75](https://github.com/jhbruhn/zugvogel/commit/fb3fb758fa142c27b8dc46b83e6d42201ca397bf))
* **tests:** the geocode cache assertions cover rounding and hit accounting ([d653dec](https://github.com/jhbruhn/zugvogel/commit/d653decaa608dbf3058f153f6b2bc98d2546dcea))
* **typst:** extract the report base, the vendor and the shared-strings seam ([976f8f5](https://github.com/jhbruhn/zugvogel/commit/976f8f56143dd5e18192b2ac2a909c5f9f4ba4c1))
* **ui:** charts and KPI cards, on the injected palette ([76e7fd4](https://github.com/jhbruhn/zugvogel/commit/76e7fd41402591074e841abf70c791ad36826e5d))
* **ui:** date field, formatLocalDate, and the sweep both apps will run ([38afede](https://github.com/jhbruhn/zugvogel/commit/38afedeac727dbe907559236523eb8c09cbfa461))
* **ui:** layout, theme scaffold and the bundled font stack ([153c2b5](https://github.com/jhbruhn/zugvogel/commit/153c2b582a831d6d5dbee6a696a3f5681799a19e))
* **ui:** let an app bind its strings without a scope in every tree ([aad784c](https://github.com/jhbruhn/zugvogel/commit/aad784c8df8fd3dfb4202f0decde2fe4f056e821))
* **ui:** map tile layer, attribution and whole-level wheel zoom ([9843d20](https://github.com/jhbruhn/zugvogel/commit/9843d20b2f99b73ce75211d2e01ef6f0cad4bc28))
* **ui:** photos and images, plus the protected-file cache ([4b40593](https://github.com/jhbruhn/zugvogel/commit/4b4059356c285a20232adcaf15f7ec4dc1b1132e))
* **ui:** state views, inputs, actions, chips and headers ([71f505b](https://github.com/jhbruhn/zugvogel/commit/71f505be3053c272b9f6a0ab61b8a266d2a6bf77))
* **ui:** the three injection boundaries, with a sweep that enforces them ([cbd1c2e](https://github.com/jhbruhn/zugvogel/commit/cbd1c2eb467de04f50ed37bb118db52f95a45465))


### Bug Fixes

* **errors:** show the message a hook wrote, instead of "could not be saved" ([fb41658](https://github.com/jhbruhn/zugvogel/commit/fb416581371e4886090c3122bcaadeb6fdf700a4))
* **errors:** surfacing the server's message is now an app's decision ([0fc74f6](https://github.com/jhbruhn/zugvogel/commit/0fc74f6faf9ea7887ffe5f19e3f7ab0ae482cd77))
* **hooks:** an edit can never move authorship ([98c011a](https://github.com/jhbruhn/zugvogel/commit/98c011a36e43606db42b771ad7e791ade347e3b9))
* **pb_client:** let an app supply the config without a scope override ([34f1914](https://github.com/jhbruhn/zugvogel/commit/34f191443a4e6fe3fd2bb665fd701290e635b610))
* **pb_client:** name every provider, and guard that they stay named ([c44b699](https://github.com/jhbruhn/zugvogel/commit/c44b699885e18100064487219542334414f465dd))
* **tests:** wait out the auth rate limit in the harness login ([3498c5d](https://github.com/jhbruhn/zugvogel/commit/3498c5de40f4571a14658f6de2811d433e176891))


### Build System

* zurück auf Flutter 3.44.3 — 3.47 verliert Bilder außerhalb von Chrome ([030c35a](https://github.com/jhbruhn/zugvogel/commit/030c35addc1622daf167212ec5c87c16fdff4696))
