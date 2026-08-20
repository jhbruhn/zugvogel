import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/host.dart';

void main() {
  group('isVideoAttachment', () {
    test('recognises the video extensions the server accepts', () {
      for (final name in [
        'clip.mp4',
        'clip.M4V',
        'clip.mov',
        'clip.QT',
        'clip.webm',
      ]) {
        expect(isVideoAttachment(name), isTrue, reason: name);
      }
    });

    test('an image is not a video', () {
      for (final name in ['photo.jpg', 'photo.JPEG', 'photo.png', 'x.heic']) {
        expect(isVideoAttachment(name), isFalse, reason: name);
      }
    });

    test('works on a bare path, which is all a picked XFile may carry', () {
      expect(isVideoAttachment('/tmp/abc/clip.mp4'), isTrue);
      expect(isVideoAttachment('/tmp/abc/photo.jpg'), isFalse);
    });

    test('no extension, or a trailing dot, is not a video', () {
      // Guessing "video" here would ask PocketBase for a thumbnail it cannot
      // make and download the original instead.
      expect(isVideoAttachment('noextension'), isFalse);
      expect(isVideoAttachment('trailing.'), isFalse);
      expect(isVideoAttachment(''), isFalse);
      expect(isVideoAttachment('.mp4'), isTrue);
    });

    testWidgets('a video gets a stand-in, since there is no thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(host(const VideoAttachmentThumb()));
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('fileCacheKey', () {
    test('strips the access token, so a rotation reuses the bytes', () {
      // Without this every token rotation looks like a new image and
      // re-downloads it.
      expect(
        fileCacheKey(
          Uri.parse('https://a.example/api/files/c/r/p.jpg?token=abc'),
        ),
        'https://a.example/api/files/c/r/p.jpg',
      );
    });

    test('keeps every OTHER query param — thumb identifies the variant', () {
      // A 100x100 thumbnail and the original are different bytes at the same
      // path; collapsing them would serve one for the other.
      final key = fileCacheKey(
        Uri.parse(
          'https://a.example/api/files/c/r/p.jpg?thumb=100x100&token=abc',
        ),
      );
      expect(key, contains('thumb=100x100'));
      expect(key, isNot(contains('token')));
    });

    test('two thumb sizes get different keys', () {
      final small = fileCacheKey(
        Uri.parse('https://a.example/p.jpg?thumb=100x100'),
      );
      final large = fileCacheKey(
        Uri.parse('https://a.example/p.jpg?thumb=800x800'),
      );
      expect(small, isNot(large));
    });

    test('a token-free URL is its own key', () {
      const url = 'https://a.example/api/files/c/r/p.jpg';
      expect(fileCacheKey(Uri.parse(url)), url);
    });

    test('query values are re-encoded, not pasted', () {
      final key = fileCacheKey(Uri.parse('https://a.example/p.jpg?q=a%20b'));
      expect(key, 'https://a.example/p.jpg?q=a+b');
    });

    test('the port is part of the identity', () {
      expect(
        fileCacheKey(Uri.parse('http://localhost:8090/p.jpg')),
        'http://localhost:8090/p.jpg',
      );
    });
  });

  group('StagedPhotos', () {
    testWidgets('shows the injected action labels', (tester) async {
      await tester.pumpWidget(
        host(
          StagedPhotos(
            photos: const [],
            enabled: true,
            onAdd: () {},
            onCapture: () {},
            onRemove: (_) {},
          ),
        ),
      );
      expect(find.text('photoAddAction'), findsOneWidget);
      expect(find.text('photoCaptureAction'), findsOneWidget);
    });

    testWidgets('disabled means both actions are dead', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          StagedPhotos(
            photos: const [],
            enabled: false,
            onAdd: () => taps++,
            onCapture: () => taps++,
            onRemove: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('photoAddAction'));
      await tester.tap(find.text('photoCaptureAction'));
      expect(taps, 0);
    });
  });
}
