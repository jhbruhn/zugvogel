import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

import 'support/config.dart';

void main() {
  group('PbClientConfig', () {
    test('derives the info route, marker and storage keys from service', () {
      final c = testConfig(service: 'eiermann');
      expect(c.infoPath, '/api/eiermann/info');
      expect(c.authStorageKey, 'eiermann.auth');
      expect(c.serverUrlStorageKey, 'eiermann.serverUrl');
      expect(c.userAgentName, 'eiermann');
    });

    test('two apps never share a storage key', () {
      // The token belongs to the origin that issued it. On web the two apps
      // can be served from the same host, so a shared key would hand one
      // app's bearer token to the other.
      expect(
        testConfig(service: 'federfall').authStorageKey,
        isNot(testConfig(service: 'eiermann').authStorageKey),
      );
    });

    test('the prefix and UA name can be overridden independently', () {
      const c = PbClientConfig(
        service: 'eiermann',
        fallbackServerName: 'Eiermann',
        mapFallback: testMapFallback,
        storageKeyPrefix: 'legacy',
        userAgentName: 'Eiermann-App',
      );
      expect(c.authStorageKey, 'legacy.auth');
      expect(c.userAgentName, 'Eiermann-App');
      // ...and the route still follows the service, not the prefix.
      expect(c.infoPath, '/api/eiermann/info');
    });

    test('an empty override counts as no override', () {
      expect(testConfig(webBaseUrlOverride: '').hasWebBaseUrlOverride, isFalse);
      expect(testConfig().hasWebBaseUrlOverride, isFalse);
      expect(
        testConfig(
          webBaseUrlOverride: 'http://localhost:8090',
        ).hasWebBaseUrlOverride,
        isTrue,
      );
    });

    test('insecure http is off unless an app asks for it', () {
      expect(testConfig().allowInsecureHttp, isFalse);
    });
  });

  group('pbClientConfigProvider', () {
    tearDown(() => defaultPbClientConfig = null);

    test('throws until the app supplies one', () {
      // Injection boundary 3: this package cannot read a define, so a config
      // that was never supplied has to fail loudly at startup rather than
      // default to something plausible and point every request at the wrong
      // /info route.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // riverpod 3 wraps a provider's own throw in a ProviderException, so
      // match on the message rather than the type.
      expect(
        () => container.read(pbClientConfigProvider),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('No PbClientConfig'),
            'reports that the app supplied no config',
          ),
        ),
      );
    });

    test('a settable default serves the scopes that cannot be overridden', () {
      // The mechanism a widget test relies on: an app of any size has tests
      // that each build their own ProviderScope, and no seam reaches all of
      // them. Set once in test/flutter_test_config.dart, and none of them has
      // to know this exists.
      defaultPbClientConfig = testConfig(service: 'defaulted');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pbClientConfigProvider).service, 'defaulted');
    });

    test('an explicit override still wins over the default', () {
      // The override is the better mechanism, so it has to outrank the
      // fallback — otherwise a test could not vary the config at all.
      defaultPbClientConfig = testConfig(service: 'defaulted');
      final container = ProviderContainer(
        overrides: [
          pbClientConfigProvider.overrideWithValue(
            testConfig(service: 'overridden'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(pbClientConfigProvider).service, 'overridden');
    });

    test('reads back what the app overrode', () {
      final container = ProviderContainer(
        overrides: [
          pbClientConfigProvider.overrideWithValue(testConfig()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(pbClientConfigProvider).service, 'testvogel');
    });
  });
}
