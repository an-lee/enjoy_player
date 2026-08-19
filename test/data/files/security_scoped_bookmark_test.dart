import 'package:enjoy_player/data/files/security_scoped_bookmark.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channel = MethodChannel(SecurityScopedBookmarkChannel.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final releaseCalls = <int>[];
  Uint8List? nextCreatedBookmark;
  ResolvedBookmark? nextResolvedBookmark;

  setUp(() {
    releaseCalls.clear();
    nextCreatedBookmark = null;
    nextResolvedBookmark = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createBookmark':
          final path = (call.arguments as Map)['path'] as String?;
          if (path == null || path.isEmpty) return null;
          return nextCreatedBookmark;
        case 'resolveBookmark':
          final data = (call.arguments as Map)['data'] as Uint8List?;
          if (data == null || data.isEmpty) return null;
          return nextResolvedBookmark == null
              ? null
              : <String, Object?>{
                  'path': nextResolvedBookmark!.path,
                  'token': nextResolvedBookmark!.token,
                  'stale': nextResolvedBookmark!.stale,
                };
        case 'releaseBookmark':
          final token = (call.arguments as Map)['token'] as int?;
          if (token != null) releaseCalls.add(token);
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('createBookmark', () {
    test('returns null when path is empty', () async {
      expect(await SecurityScopedBookmarkChannel.createBookmark(''), isNull);
    });

    test('returns the bytes from the native shim', () async {
      nextCreatedBookmark = Uint8List.fromList([10, 20, 30]);
      final got = await SecurityScopedBookmarkChannel.createBookmark(
        '/Users/an-lee/Downloads/foo.mp4',
      );
      expect(got, equals(Uint8List.fromList([10, 20, 30])));
    });

    test('returns null when native shim throws PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOKMARK_FAILED', message: 'nope');
      });
      final got = await SecurityScopedBookmarkChannel.createBookmark('/x');
      expect(got, isNull);
    });

    test(
      'returns null when no native shim is registered (MissingPlugin)',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });
        final got = await SecurityScopedBookmarkChannel.createBookmark('/x');
        expect(got, isNull);
      },
    );
  });

  group('resolveBookmark', () {
    test('returns ResolvedBookmark on success', () async {
      nextResolvedBookmark = const ResolvedBookmark(
        path: '/Users/an-lee/Movies/v.mp4',
        token: 42,
        stale: false,
      );
      final got = await SecurityScopedBookmarkChannel.resolveBookmark(
        Uint8List.fromList([1]),
      );
      expect(got?.path, '/Users/an-lee/Movies/v.mp4');
      expect(got?.token, 42);
      expect(got?.stale, isFalse);
    });

    test('reports stale=true when bookmark re-bound', () async {
      nextResolvedBookmark = const ResolvedBookmark(
        path: '/Users/an-lee/Movies/v.mp4',
        token: 1,
        stale: true,
      );
      final got = await SecurityScopedBookmarkChannel.resolveBookmark(
        Uint8List.fromList([1]),
      );
      expect(got?.stale, isTrue);
    });

    test('returns null when data is empty', () async {
      expect(
        await SecurityScopedBookmarkChannel.resolveBookmark(Uint8List(0)),
        isNull,
      );
    });

    test('returns null when the shim is missing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      expect(
        await SecurityScopedBookmarkChannel.resolveBookmark(
          Uint8List.fromList([1]),
        ),
        isNull,
      );
    });

    test('returns null when shim returns a malformed payload', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'resolveBookmark') {
          return <String, Object?>{'path': null, 'token': 'oops'};
        }
        return null;
      });
      expect(
        await SecurityScopedBookmarkChannel.resolveBookmark(
          Uint8List.fromList([1]),
        ),
        isNull,
      );
    });
  });

  group('releaseBookmark', () {
    test('forwards the token to the native shim', () async {
      await SecurityScopedBookmarkChannel.releaseBookmark(7);
      expect(releaseCalls, [7]);
    });

    test('silently no-ops when shim throws MissingPlugin', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      await SecurityScopedBookmarkChannel.releaseBookmark(99);
    });

    test('silently no-ops on PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOM', message: 'explode');
      });
      await SecurityScopedBookmarkChannel.releaseBookmark(99);
    });
  });
}
