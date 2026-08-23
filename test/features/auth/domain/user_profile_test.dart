import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses mixinId when present', () {
      final p = UserProfile.fromJson({
        'id': '24000001',
        'email': 'a@b.com',
        'name': 'Ada',
        'mixinId': '12345678',
        'hasMixin': true,
      });
      expect(p.id, '24000001');
      expect(p.mixinId, '12345678');
      expect(p.hasMixin, isTrue);
    });

    test('leaves mixinId null when absent', () {
      final p = UserProfile.fromJson({
        'id': '24000001',
        'email': 'a@b.com',
        'name': 'Ada',
        'hasMixin': false,
      });
      expect(p.mixinId, isNull);
    });

    test('round-trips mixinId through toJson', () {
      const original = UserProfile(
        id: '1',
        email: 'e@x.com',
        name: 'N',
        mixinId: '99',
      );
      final again = UserProfile.fromJson(original.toJson());
      expect(again.mixinId, '99');
    });

    test('parses all fields from full JSON', () {
      final p = UserProfile.fromJson({
        'id': 42,
        'email': 'test@example.com',
        'name': 'Test User',
        'avatarUrl': 'https://example.com/avatar.png',
        'balance': 99.5,
        'hasMixin': true,
        'mixinId': '12345',
        'subscriptionTier': 'pro',
        'subscriptionExpireDate': '2027-01-01',
        'locale': 'en',
        'learningLanguage': 'zh',
        'nativeLanguage': 'en',
        'goal': 10,
        'createdAt': '2025-01-01T00:00:00Z',
      });
      expect(p.id, '42');
      expect(p.email, 'test@example.com');
      expect(p.name, 'Test User');
      expect(p.avatarUrl, 'https://example.com/avatar.png');
      expect(p.balance, 99.5);
      expect(p.hasMixin, isTrue);
      expect(p.mixinId, '12345');
      expect(p.subscriptionTier, SubscriptionTier.pro);
      expect(p.subscriptionExpireDate, '2027-01-01');
      expect(p.locale, 'en');
      expect(p.learningLanguage, 'zh');
      expect(p.nativeLanguage, 'en');
      expect(p.goal, 10);
      expect(p.createdAt, '2025-01-01T00:00:00Z');
    });

    test('handles missing optional fields gracefully', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': 'a@b.com',
        'name': 'A',
      });
      expect(p.avatarUrl, isNull);
      expect(p.balance, isNull);
      expect(p.hasMixin, isNull);
      expect(p.subscriptionTier, isNull);
      expect(p.goal, isNull);
    });

    test('parses subscriptionTier as free for unknown values', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'subscriptionTier': 'enterprise',
      });
      expect(p.subscriptionTier, SubscriptionTier.free);
    });

    test('parses subscriptionTier null when absent', () {
      final p = UserProfile.fromJson({'id': '1', 'email': '', 'name': ''});
      expect(p.subscriptionTier, isNull);
    });

    test('parses balance from string', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'balance': '42.5',
      });
      expect(p.balance, 42.5);
    });

    test('parses balance from int', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'balance': 10,
      });
      expect(p.balance, 10.0);
    });

    test('parses goal from double', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'goal': 5.0,
      });
      expect(p.goal, 5);
    });

    test('parses goal from string', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'goal': '7',
      });
      expect(p.goal, 7);
    });

    test('rewrites dicebear svg avatar to png', () {
      final p = UserProfile.fromJson({
        'id': '1',
        'email': '',
        'name': '',
        'avatarUrl': 'https://api.dicebear.com/7.x/thumbs/svg?seed=x',
      });
      expect(p.avatarUrl, contains('/png'));
    });
  });

  group('subscriptionTierFromJson', () {
    test('decodes pro and lite case-insensitively', () {
      expect(subscriptionTierFromJson('PRO'), SubscriptionTier.pro);
      expect(subscriptionTierFromJson('Lite'), SubscriptionTier.lite);
      expect(subscriptionTierFromJson('free'), SubscriptionTier.free);
    });

    test('falls back to free for unknown strings', () {
      expect(subscriptionTierFromJson('enterprise'), SubscriptionTier.free);
      expect(subscriptionTierFromJson(''), SubscriptionTier.free);
    });

    test('returns null only for explicit null input', () {
      expect(subscriptionTierFromJson(null), isNull);
      expect(subscriptionTierFromJson(0), SubscriptionTier.free);
    });
  });

  group('UserProfile.toJson', () {
    test('omits null fields', () {
      const p = UserProfile(id: '1', email: 'e@x.com', name: 'N');
      final json = p.toJson();
      expect(json.containsKey('avatarUrl'), isFalse);
      expect(json.containsKey('balance'), isFalse);
      expect(json.containsKey('hasMixin'), isFalse);
      expect(json.containsKey('mixinId'), isFalse);
      expect(json.containsKey('subscriptionTier'), isFalse);
      expect(json.containsKey('goal'), isFalse);
    });

    test('includes non-null fields', () {
      const p = UserProfile(
        id: '1',
        email: 'e@x.com',
        name: 'N',
        balance: 5.0,
        subscriptionTier: SubscriptionTier.pro,
        goal: 10,
      );
      final json = p.toJson();
      expect(json['balance'], 5.0);
      expect(json['subscriptionTier'], 'pro');
      expect(json['goal'], 10);
    });
  });

  group('UserProfile.copyWith', () {
    test('overrides specified fields', () {
      const original = UserProfile(
        id: '1',
        email: 'old@x.com',
        name: 'Old',
        goal: 5,
      );
      final updated = original.copyWith(name: 'New', goal: 10);
      expect(updated.name, 'New');
      expect(updated.goal, 10);
      expect(updated.email, 'old@x.com');
      expect(updated.id, '1');
    });

    test('preserves all fields when no overrides', () {
      const original = UserProfile(
        id: '1',
        email: 'e@x.com',
        name: 'N',
        avatarUrl: 'https://example.com/a.png',
        balance: 3.14,
        hasMixin: true,
        mixinId: '42',
        subscriptionTier: SubscriptionTier.pro,
        locale: 'en',
        learningLanguage: 'zh',
        nativeLanguage: 'en',
        goal: 7,
        createdAt: '2025-01-01',
      );
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.email, original.email);
      expect(copy.avatarUrl, original.avatarUrl);
      expect(copy.balance, original.balance);
      expect(copy.hasMixin, original.hasMixin);
      expect(copy.mixinId, original.mixinId);
      expect(copy.subscriptionTier, original.subscriptionTier);
      expect(copy.locale, original.locale);
      expect(copy.learningLanguage, original.learningLanguage);
      expect(copy.nativeLanguage, original.nativeLanguage);
      expect(copy.goal, original.goal);
      expect(copy.createdAt, original.createdAt);
    });
  });
}
