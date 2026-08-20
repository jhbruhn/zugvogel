import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';
import 'package:zugvogel_data/zugvogel_data.dart';

void main() {
  group('RepositoryException.fromClient', () {
    RepositoryException of(int status) =>
        RepositoryException.fromClient(ClientException(statusCode: status));

    test('classifies by status code', () {
      expect(of(0).kind, RepositoryErrorKind.network);
      expect(of(0).isNetwork, isTrue);
      expect(of(401).kind, RepositoryErrorKind.unauthorized);
      expect(of(403).kind, RepositoryErrorKind.unauthorized);
      expect(of(404).kind, RepositoryErrorKind.notFound);
      expect(of(400).kind, RepositoryErrorKind.validation);
      expect(of(422).kind, RepositoryErrorKind.validation);
      expect(of(500).kind, RepositoryErrorKind.unknown);
    });

    test('preserves status and cause', () {
      final e = of(404);
      expect(e.statusCode, 404);
      expect(e.cause, isA<ClientException>());
    });

    test('never produces unknownOutcome — a ClientException means the '
        'server answered', () {
      for (final status in [0, 400, 401, 403, 404, 422, 500, 503]) {
        expect(of(status).kind, isNot(RepositoryErrorKind.unknownOutcome));
      }
    });

    test('toString names the kind and status, for a log line', () {
      expect(of(404).toString(), contains('notFound'));
      expect(of(404).toString(), contains('404'));
    });
  });
}
