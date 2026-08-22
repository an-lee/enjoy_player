// Tests for `lib/features/craft/domain/craft_edit_source.dart` — immutable
// snapshot DTO with `==` / `hashCode` covering every constructor field.
import 'package:enjoy_player/features/craft/domain/craft_edit_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = CraftEditSource(
    mediaId: 'media-1',
    practiceText: 'hola mundo',
    sourceText: 'hello world',
    language: 'es',
    voice: 'es-ES-ElviraNeural',
    sourceFlag: 'craft-express',
  );

  test('constructor stores every field', () {
    expect(base.mediaId, 'media-1');
    expect(base.practiceText, 'hola mundo');
    expect(base.sourceText, 'hello world');
    expect(base.language, 'es');
    expect(base.voice, 'es-ES-ElviraNeural');
    expect(base.sourceFlag, 'craft-express');
  });

  test('nullable optional fields default to null', () {
    const a = CraftEditSource(mediaId: 'm', practiceText: 'p', language: 'en');
    expect(a.sourceText, isNull);
    expect(a.voice, isNull);
    expect(a.sourceFlag, isNull);
  });

  test('value equality requires every field to match', () {
    expect(
      base,
      equals(
        const CraftEditSource(
          mediaId: 'media-1',
          practiceText: 'hola mundo',
          sourceText: 'hello world',
          language: 'es',
          voice: 'es-ES-ElviraNeural',
          sourceFlag: 'craft-express',
        ),
      ),
    );
  });

  test('equality returns false when a single field differs', () {
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'media-1',
            practiceText: 'hola mundo',
            sourceText: 'hello world',
            language: 'fr', // differs
            voice: 'es-ES-ElviraNeural',
            sourceFlag: 'craft-express',
          ),
        ),
      ),
    );
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'other', // differs
            practiceText: 'hola mundo',
            sourceText: 'hello world',
            language: 'es',
            voice: 'es-ES-ElviraNeural',
            sourceFlag: 'craft-express',
          ),
        ),
      ),
    );
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'media-1',
            practiceText: 'adiós', // differs
            sourceText: 'hello world',
            language: 'es',
            voice: 'es-ES-ElviraNeural',
            sourceFlag: 'craft-express',
          ),
        ),
      ),
    );
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'media-1',
            practiceText: 'hola mundo',
            sourceText: 'goodbye', // differs
            language: 'es',
            voice: 'es-ES-ElviraNeural',
            sourceFlag: 'craft-express',
          ),
        ),
      ),
    );
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'media-1',
            practiceText: 'hola mundo',
            sourceText: 'hello world',
            language: 'es',
            voice: 'es-ES-AriaNeural', // differs
            sourceFlag: 'craft-express',
          ),
        ),
      ),
    );
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'media-1',
            practiceText: 'hola mundo',
            sourceText: 'hello world',
            language: 'es',
            voice: 'es-ES-ElviraNeural',
            sourceFlag: 'craft-direct', // differs
          ),
        ),
      ),
    );
  });

  test('hashCode is identical for value-equal instances', () {
    const clone = CraftEditSource(
      mediaId: 'media-1',
      practiceText: 'hola mundo',
      sourceText: 'hello world',
      language: 'es',
      voice: 'es-ES-ElviraNeural',
      sourceFlag: 'craft-express',
    );
    expect(base.hashCode, clone.hashCode);
  });

  test('hashCode differs when any field differs', () {
    const other = CraftEditSource(
      mediaId: 'media-1',
      practiceText: 'hola mundo',
      sourceText: 'hello world',
      language: 'fr',
      voice: 'es-ES-ElviraNeural',
      sourceFlag: 'craft-express',
    );
    expect(base.hashCode, isNot(other.hashCode));
  });

  test('identical instances are equal to themselves', () {
    expect(base, equals(base));
    expect(
      base,
      isNot(
        equals(
          const CraftEditSource(
            mediaId: 'm2',
            practiceText: 'p',
            language: 'en',
          ),
        ),
      ),
    );
  });
}
