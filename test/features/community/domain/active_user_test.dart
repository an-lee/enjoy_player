import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveUser.fromJson', () {
    test('parses a fully-populated user', () {
      final u = ActiveUser.fromJson({
        'id': 42,
        'name': 'Alice',
        'avatarUrl': 'https://example.com/a.png',
      });
      expect(u.id, '42');
      expect(u.name, 'Alice');
      expect(u.avatarUrl, isNotNull);
    });

    test('falls back to empty strings when fields are missing', () {
      final u = ActiveUser.fromJson(const {});
      expect(u.id, '');
      expect(u.name, '');
      expect(u.avatarUrl, isNull);
    });

    test('returns empty id when id field is missing', () {
      final u = ActiveUser.fromJson({'name': 'A'});
      expect(u.id, '');
    });
  });

  group('ActiveUsersResponse.fromJson', () {
    test('parses a populated users array + counts', () {
      final r = ActiveUsersResponse.fromJson({
        'users': [
          {'id': '1', 'name': 'A'},
          {'id': '2', 'name': 'B'},
        ],
        'count': 7,
        'recordingsCountToday': 3,
        'recordingsDurationToday': 12345,
      });
      expect(r.users, hasLength(2));
      expect(r.count, 7);
      expect(r.recordingsCountToday, 3);
      expect(r.recordingsDurationToday, 12345);
    });

    test('uses users.length when count is missing', () {
      final r = ActiveUsersResponse.fromJson({
        'users': [
          {'id': '1', 'name': 'A'},
          {'id': '2', 'name': 'B'},
          {'id': '3', 'name': 'C'},
        ],
      });
      expect(r.count, 3);
    });

    test('skips non-object entries in the users array', () {
      final r = ActiveUsersResponse.fromJson({
        'users': [
          {'id': '1', 'name': 'A'},
          'invalid-string-entry',
          42,
          null,
          {'id': '2', 'name': 'B'},
        ],
      });
      expect(r.users, hasLength(2));
    });

    test('returns empty response when users is missing or non-list', () {
      final r1 = ActiveUsersResponse.fromJson(const {});
      expect(r1.users, isEmpty);
      expect(r1.count, 0);

      final r2 = ActiveUsersResponse.fromJson({'users': 'not a list'});
      expect(r2.users, isEmpty);
      expect(r2.count, 0);
    });

    test('optional count fields default to null', () {
      final r = ActiveUsersResponse.fromJson({'users': [], 'count': 0});
      expect(r.recordingsCountToday, isNull);
      expect(r.recordingsDurationToday, isNull);
    });
  });
}
