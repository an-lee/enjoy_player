/// Tests for [PlayerLaunchRequest] — the URI-encoded open options for the
/// expanded `/player/:mediaId` route.
///
/// The request is the contract between three independent surfaces:
///   1. GoRouter parsing (`fromUri`),
///   2. The typed call-site constructors (including `vocabularyOpenSource`),
///   3. Round-tripping back to a route string via [PlayerLaunchRequest.location].
///
/// The serializer collapses integer-valued doubles (e.g. `12.0`) to their
/// integer form (`12`) so the URL stays human-readable; tests pin that
/// behavior because GoRouter treats `?start=12` and `?start=12.0` as
/// distinct query strings that must round-trip identically.
library;

import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerLaunchRequest', () {
    group('constructor', () {
      test('applies documented defaults', () {
        const request = PlayerLaunchRequest(mediaId: 'm1');

        expect(request.mediaId, 'm1');
        expect(request.startSec, isNull);
        expect(request.endSec, isNull);
        expect(request.autoplay, isFalse);
        expect(request.activateClipWindow, isFalse);
        expect(request.mode, PlayerLaunchMode.expanded);
        expect(request.restoreSession, isNull);
      });
    });

    group('vocabularyOpenSource', () {
      test('produces an explicit autoplay + clip launch with no restore', () {
        final request = PlayerLaunchRequest.vocabularyOpenSource(
          mediaId: 'vocab-42',
          startSec: 3.5,
          endSec: 18.25,
        );

        expect(request.mediaId, 'vocab-42');
        expect(request.startSec, 3.5);
        expect(request.endSec, 18.25);
        expect(request.autoplay, isTrue);
        expect(request.activateClipWindow, isTrue);
        expect(
          request.restoreSession,
          isFalse,
          reason: 'Vocabulary launches are explicit and must not restore.',
        );
        expect(request.shouldRestoreSession, isFalse);
        expect(request.isExplicitLaunch, isTrue);
      });
    });

    group('fromUri', () {
      test('parses a bare /player/:id URI with no query parameters', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1'),
          mediaId: 'm1',
        );

        expect(request.mediaId, 'm1');
        expect(request.startSec, isNull);
        expect(request.endSec, isNull);
        expect(request.autoplay, isFalse);
        expect(request.activateClipWindow, isFalse);
        expect(request.restoreSession, isNull);
      });

      test('parses start/end with integer-valued doubles verbatim', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?start=12&end=30'),
          mediaId: 'm1',
        );

        expect(request.startSec, 12.0);
        expect(request.endSec, 30.0);
      });

      test('parses fractional start/end positions', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?start=3.5&end=18.25'),
          mediaId: 'm1',
        );

        expect(request.startSec, 3.5);
        expect(request.endSec, 18.25);
      });

      test('drops malformed start/end to null instead of throwing', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?start=abc&end='),
          mediaId: 'm1',
        );

        expect(request.startSec, isNull);
        expect(request.endSec, isNull);
      });

      test('recognizes autoplay=1 and autoplay=true as truthy', () {
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?autoplay=1'),
            mediaId: 'm1',
          ).autoplay,
          isTrue,
        );
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?autoplay=true'),
            mediaId: 'm1',
          ).autoplay,
          isTrue,
        );
      });

      test('treats any other autoplay value as falsy', () {
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?autoplay=0'),
            mediaId: 'm1',
          ).autoplay,
          isFalse,
        );
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?autoplay=yes'),
            mediaId: 'm1',
          ).autoplay,
          isFalse,
        );
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?autoplay='),
            mediaId: 'm1',
          ).autoplay,
          isFalse,
        );
      });

      test('recognizes clip=1 and clip=true as truthy, others as falsy', () {
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?clip=1'),
            mediaId: 'm1',
          ).activateClipWindow,
          isTrue,
        );
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?clip=true'),
            mediaId: 'm1',
          ).activateClipWindow,
          isTrue,
        );
        expect(
          PlayerLaunchRequest.fromUri(
            Uri.parse('/player/m1?clip=0'),
            mediaId: 'm1',
          ).activateClipWindow,
          isFalse,
        );
      });

      test('decode norestore to restoreSession=false', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?norestore=1'),
          mediaId: 'm1',
        );

        expect(request.restoreSession, isFalse);
      });

      test('decode restore to restoreSession=true', () {
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?restore=1'),
          mediaId: 'm1',
        );

        expect(request.restoreSession, isTrue);
      });

      test('restore wins over norestore when both are present', () {
        // Both keys may appear in legacy URLs; the implementation applies
        // them in order, so the later one (restore) wins.
        final request = PlayerLaunchRequest.fromUri(
          Uri.parse('/player/m1?norestore=1&restore=1'),
          mediaId: 'm1',
        );

        expect(request.restoreSession, isTrue);
      });
    });

    group('shouldRestoreSession', () {
      test(
        'defaults to true when restoreSession is null and no clip/start',
        () {
          const request = PlayerLaunchRequest(mediaId: 'm1');

          expect(request.restoreSession, isNull);
          expect(request.shouldRestoreSession, isTrue);
          expect(request.isExplicitLaunch, isFalse);
        },
      );

      test('defaults to false when startSec is set', () {
        const request = PlayerLaunchRequest(mediaId: 'm1', startSec: 5);

        expect(request.shouldRestoreSession, isFalse);
        expect(request.isExplicitLaunch, isTrue);
      });

      test('defaults to false when activateClipWindow is set', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          activateClipWindow: true,
        );

        expect(request.shouldRestoreSession, isFalse);
        expect(request.isExplicitLaunch, isTrue);
      });

      test('honors explicit restoreSession=true', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          startSec: 5,
          restoreSession: true,
        );

        expect(request.shouldRestoreSession, isTrue);
        expect(request.isExplicitLaunch, isFalse);
      });

      test('honors explicit restoreSession=false', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          restoreSession: false,
        );

        expect(request.shouldRestoreSession, isFalse);
        expect(request.isExplicitLaunch, isTrue);
      });
    });

    group('location', () {
      test('omits the query string entirely when no params are set', () {
        const request = PlayerLaunchRequest(mediaId: 'm1');

        expect(request.location, '/player/m1');
      });

      test('preserves fractional seconds verbatim', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          startSec: 3.5,
          endSec: 18.25,
        );

        final uri = Uri.parse(request.location);
        expect(uri.path, '/player/m1');
        expect(uri.queryParameters, {'start': '3.5', 'end': '18.25'});
      });

      test('emits autoplay=1 only when autoplay is true', () {
        const onRequest = PlayerLaunchRequest(mediaId: 'm1', autoplay: true);
        const offRequest = PlayerLaunchRequest(mediaId: 'm1', autoplay: false);

        expect(onRequest.location, '/player/m1?autoplay=1');
        expect(offRequest.location, '/player/m1');
      });

      test('emits clip=1 only when activateClipWindow is true', () {
        const onRequest = PlayerLaunchRequest(
          mediaId: 'm1',
          activateClipWindow: true,
        );
        const offRequest = PlayerLaunchRequest(
          mediaId: 'm1',
          activateClipWindow: false,
        );

        expect(onRequest.location, '/player/m1?clip=1');
        expect(offRequest.location, '/player/m1');
      });

      test(
        'emits norestore=1 only when restoreSession is explicitly false',
        () {
          const request = PlayerLaunchRequest(
            mediaId: 'm1',
            restoreSession: false,
          );

          expect(request.location, '/player/m1?norestore=1');
        },
      );

      test('emits restore=1 only when restoreSession is explicitly true', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          restoreSession: true,
        );

        expect(request.location, '/player/m1?restore=1');
      });

      test('omits both restore flags when restoreSession is null', () {
        const request = PlayerLaunchRequest(mediaId: 'm1');

        // The query should not contain norestore nor restore.
        expect(request.location, '/player/m1');
        expect(request.location.contains('norestore'), isFalse);
        expect(request.location.contains('restore'), isFalse);
      });

      test('serializes all five params for vocabularyOpenSource', () {
        final request = PlayerLaunchRequest.vocabularyOpenSource(
          mediaId: 'vocab-42',
          startSec: 3,
          endSec: 18,
        );

        // Assert per-parameter rather than the literal query string so
        // the test is robust to Dart's `Uri.toString()` key-order policy.
        final uri = Uri.parse(request.location);
        expect(uri.path, '/player/vocab-42');
        expect(uri.queryParameters, {
          'start': '3',
          'end': '18',
          'autoplay': '1',
          'clip': '1',
          'norestore': '1',
        });
        // Every key present exactly once — guards against accidental
        // double-emission of norestore + restore, or repeated start.
        expect(uri.queryParametersAll.values.expand((v) => v).length, 5);
        expect(uri.queryParametersAll.keys.toSet(), {
          'start',
          'end',
          'autoplay',
          'clip',
          'norestore',
        });
      });

      test('emits integer-form doubles without a trailing .0', () {
        const request = PlayerLaunchRequest(
          mediaId: 'm1',
          startSec: 12,
          endSec: 30,
        );

        // 12.0 / 30.0 must collapse to "12" / "30" so URLs stay short.
        // Assert per-parameter rather than the literal query string so
        // the test is robust to Dart's `Uri.toString()` key-order policy.
        final uri = Uri.parse(request.location);
        expect(uri.path, '/player/m1');
        expect(uri.queryParameters, {'start': '12', 'end': '30'});
      });
    });

    group('round-trip', () {
      test('fromUri(location) is stable for a minimal request', () {
        const original = PlayerLaunchRequest(mediaId: 'm1');

        final parsed = PlayerLaunchRequest.fromUri(
          Uri.parse(original.location),
          mediaId: 'm1',
        );

        expect(parsed, original);
      });

      test('fromUri(location) is stable for a fully populated request', () {
        final original = PlayerLaunchRequest.vocabularyOpenSource(
          mediaId: 'vocab-42',
          startSec: 3.5,
          endSec: 18.25,
        );

        final parsed = PlayerLaunchRequest.fromUri(
          Uri.parse(original.location),
          mediaId: 'vocab-42',
        );

        expect(parsed.mediaId, original.mediaId);
        expect(parsed.startSec, original.startSec);
        expect(parsed.endSec, original.endSec);
        expect(parsed.autoplay, original.autoplay);
        expect(parsed.activateClipWindow, original.activateClipWindow);
        // vocabularyOpenSource explicitly sets restoreSession=false; the
        // serialized form uses norestore=1, which fromUri decodes back to
        // false, so the boolean round-trips even though the key names
        // differ.
        expect(parsed.restoreSession, original.restoreSession);
      });
    });

    group('equality', () {
      test(
        'two requests with the same fields are equal and share hashCode',
        () {
          const a = PlayerLaunchRequest(
            mediaId: 'm1',
            startSec: 3.5,
            endSec: 18.25,
            autoplay: true,
            activateClipWindow: true,
            restoreSession: false,
          );
          const b = PlayerLaunchRequest(
            mediaId: 'm1',
            startSec: 3.5,
            endSec: 18.25,
            autoplay: true,
            activateClipWindow: true,
            restoreSession: false,
          );

          expect(a, equals(b));
          expect(a.hashCode, b.hashCode);
        },
      );

      test('different mediaId breaks equality', () {
        const a = PlayerLaunchRequest(mediaId: 'm1');
        const b = PlayerLaunchRequest(mediaId: 'm2');

        expect(a, isNot(equals(b)));
      });

      test('different startSec breaks equality', () {
        const a = PlayerLaunchRequest(mediaId: 'm1', startSec: 1);
        const b = PlayerLaunchRequest(mediaId: 'm1', startSec: 2);

        expect(a, isNot(equals(b)));
      });

      test('different restoreSession breaks equality', () {
        const a = PlayerLaunchRequest(mediaId: 'm1', restoreSession: true);
        const b = PlayerLaunchRequest(mediaId: 'm1', restoreSession: false);

        expect(a, isNot(equals(b)));
      });

      test('a request with restoreSession=null differs from both '
          'true and false', () {
        const none = PlayerLaunchRequest(mediaId: 'm1');
        const yes = PlayerLaunchRequest(mediaId: 'm1', restoreSession: true);
        const no = PlayerLaunchRequest(mediaId: 'm1', restoreSession: false);

        expect(none, isNot(equals(yes)));
        expect(none, isNot(equals(no)));
      });
    });
  });
}
