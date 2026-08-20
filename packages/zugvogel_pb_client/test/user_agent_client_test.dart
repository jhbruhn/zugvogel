import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as testing;
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

void main() {
  group('UserAgentClient', () {
    test('stamps the User-Agent on every request', () async {
      // The PocketBase Dart SDK never sets one, so requests otherwise go out
      // as `Dart/<v> (dart:io)`.
      final seen = <String?>[];
      final client = UserAgentClient(
        'testvogel/1.2.3',
        testing.MockClient((request) async {
          seen.add(request.headers['user-agent']);
          return http.Response('', 200);
        }),
      );
      addTearDown(client.close);

      await client.get(Uri.parse('https://a.example/one'));
      await client.get(Uri.parse('https://a.example/two'));

      expect(seen, ['testvogel/1.2.3', 'testvogel/1.2.3']);
    });

    test('overrides a User-Agent the caller already set', () async {
      String? seen;
      final client = UserAgentClient(
        'testvogel/1.2.3',
        testing.MockClient((request) async {
          seen = request.headers['user-agent'];
          return http.Response('', 200);
        }),
      );
      addTearDown(client.close);

      await client.get(
        Uri.parse('https://a.example'),
        headers: {'user-agent': 'something-else'},
      );

      expect(seen, 'testvogel/1.2.3');
    });
  });
}
