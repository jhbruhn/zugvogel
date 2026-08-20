// Placeholder while Phase 00 is still moving code in. The import of the
// package itself IS the assertion: it proves the pub workspace resolves and
// that this package compiles on its own. A test runner also fails outright on
// a package with no test files, so the repo skeleton needs one per package.
//
// Delete this file once eiermann-d2a.4 lands real tests here.
import 'package:flutter_test/flutter_test.dart';
// Deliberately unused: importing an as-yet-empty library is the whole point
// of this test.
// ignore: unused_import
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

void main() {
  test('package resolves and compiles', () {
    expect(true, isTrue);
  });
}
