import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_blur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('line-only JSON', () {
    test('toJson is text/start/duration only', () {
      const line = TranscriptLine(text: 'Hello', startMs: 100, durationMs: 400);
      expect(line.toJson(), {'text': 'Hello', 'start': 100, 'duration': 400});
      expect(line.toJson().containsKey('timeline'), isFalse);
      expect(line.toJson().containsKey('words'), isFalse);
    });

    test('toJson includes sourceKey when set and omits timeline', () {
      const line = TranscriptLine(
        text: 'Hello',
        startMs: 0,
        durationMs: 100,
        sourceKey: 'abc',
      );
      expect(line.toJson(), {
        'text': 'Hello',
        'start': 0,
        'duration': 100,
        'sourceKey': 'abc',
      });
      expect(line.toJson().containsKey('timeline'), isFalse);
    });

    test('fromJson of historical cue yields timeline == null', () {
      final line = TranscriptLine.fromJson({
        'text': 'Hello',
        'start': 100,
        'duration': 400,
      });
      expect(line.text, 'Hello');
      expect(line.startMs, 100);
      expect(line.durationMs, 400);
      expect(line.timeline, isNull);
    });

    test('round-trip does not invent nested spans', () {
      const original = TranscriptLine(
        text: 'Hello',
        startMs: 0,
        durationMs: 250,
      );
      final roundTripped = TranscriptLine.fromJson(original.toJson());
      expect(roundTripped, original);
      expect(roundTripped.timeline, isNull);
    });

    test('empty timeline list is omitted on write and equals line-only', () {
      const line = TranscriptLine(
        text: 'Hi',
        startMs: 0,
        durationMs: 10,
        timeline: [],
      );
      expect(line.toJson().containsKey('timeline'), isFalse);
      expect(
        line,
        const TranscriptLine(text: 'Hi', startMs: 0, durationMs: 10),
      );
      expect(TranscriptLine.fromJson(line.toJson()).timeline, isNull);
    });
  });

  group('enjoy web nested JSON', () {
    test('round-trips timeline + phones (PhoneTiming seconds)', () {
      const line = TranscriptLine(
        text: 'Hello world.',
        startMs: 0,
        durationMs: 1200,
        confidence: 0.9,
        timeline: [
          TranscriptWord(
            text: 'Hello',
            startMs: 0,
            durationMs: 500,
            phones: [
              TranscriptPhone(
                phone: 'h',
                text: 'h',
                startTime: 0,
                endTime: 0.08,
                wordIndex: 0,
              ),
              TranscriptPhone(
                phone: 'əˈ',
                text: 'əˈ',
                startTime: 0.08,
                endTime: 0.28,
                wordIndex: 0,
              ),
              TranscriptPhone(
                phone: 'loʊ',
                text: 'loʊ',
                startTime: 0.28,
                endTime: 0.5,
                wordIndex: 0,
              ),
            ],
          ),
          TranscriptWord(text: 'world', startMs: 520, durationMs: 600),
          TranscriptWord(text: '.'),
        ],
      );

      final json = line.toJson();
      expect(json['text'], 'Hello world.');
      expect(json['start'], 0);
      expect(json['duration'], 1200);
      expect(json['confidence'], 0.9);
      expect(json.containsKey('words'), isFalse);
      expect(json['timeline'], isA<List<dynamic>>());
      expect((json['timeline'] as List).length, 3);

      final hello = (json['timeline'] as List)[0] as Map<String, dynamic>;
      expect(hello['phones'], isA<List<dynamic>>());
      final firstPhone =
          (hello['phones'] as List).first as Map<String, dynamic>;
      expect(firstPhone['phone'], 'h');
      expect(firstPhone['startTime'], 0);
      expect(firstPhone['endTime'], 0.08);
      expect(firstPhone.containsKey('ipa'), isFalse);
      expect(firstPhone.containsKey('start'), isFalse);

      final world = (json['timeline'] as List)[1] as Map<String, dynamic>;
      expect(world.containsKey('phones'), isFalse);
      expect(world.containsKey('ipa'), isFalse);

      final period = (json['timeline'] as List)[2] as Map<String, dynamic>;
      expect(period, {'text': '.', 'start': 0, 'duration': 0});

      expect(TranscriptLine.fromJson(json), line);
    });

    test('parses enjoy web fixture with relative word ms and PhoneTiming', () {
      final line = TranscriptLine.fromJson({
        'text': 'hello world',
        'start': 0,
        'duration': 2000,
        'timeline': [
          {
            'text': 'hello',
            'start': 0,
            'duration': 1000,
            'phones': [
              {
                'phone': 'h',
                'text': 'h',
                'startTime': 0,
                'endTime': 0.5,
                'wordIndex': 0,
              },
            ],
          },
          {'text': 'world', 'start': 1000, 'duration': 1000},
        ],
      });
      expect(line.timeline, hasLength(2));
      expect(line.timeline![0].startMs, 0);
      expect(line.timeline![0].phones!.single.phone, 'h');
      expect(line.timeline![0].phones!.single.startTime, 0);
      expect(line.timeline![1].startMs, 1000);
      expect(line.timeline![1].phones, isNull);
    });

    test('ignores a words key; nested words are only timeline', () {
      final line = TranscriptLine.fromJson({
        'text': 'Hello',
        'start': 0,
        'duration': 500,
        'words': [
          {'text': 'Hello', 'start': 0, 'duration': 500},
        ],
      });
      expect(line.timeline, isNull);
    });

    test('ignores nested timeline on a word; phones are only phones', () {
      final line = TranscriptLine.fromJson({
        'text': 'Hello',
        'start': 0,
        'duration': 800,
        'timeline': [
          {
            'text': 'Hello',
            'start': 0,
            'duration': 800,
            'timeline': [
              {'text': 'h', 'start': 0, 'duration': 80},
            ],
          },
        ],
      });
      expect(line.timeline, hasLength(1));
      expect(line.timeline!.single.phones, isNull);
    });
  });

  group('malformed nested JSON', () {
    test('timeline not a list keeps line fields', () {
      final line = TranscriptLine.fromJson({
        'text': 'Keep me',
        'start': 5,
        'duration': 15,
        'timeline': 'nope',
      });
      expect(line.text, 'Keep me');
      expect(line.startMs, 5);
      expect(line.durationMs, 15);
      expect(line.timeline, isNull);
    });

    test('non-object word elements and empty text are skipped', () {
      final line = TranscriptLine.fromJson({
        'text': 'Keep me',
        'start': 0,
        'duration': 100,
        'timeline': [
          'skip',
          {'text': ''},
          {'text': 'ok', 'start': 10, 'duration': 20},
          42,
        ],
      });
      expect(line.text, 'Keep me');
      expect(line.timeline, hasLength(1));
      expect(line.timeline!.single.text, 'ok');
      expect(line.timeline!.single.startMs, 10);
    });

    test('empty phone label is skipped; fromJson does not throw', () {
      final line = TranscriptLine.fromJson({
        'text': 'Keep me',
        'start': 0,
        'duration': 100,
        'timeline': [
          {
            'text': 'Hi',
            'start': 0,
            'duration': 100,
            'phones': [
              {'phone': ''},
              {'phone': 'h', 'text': 'h', 'startTime': 0, 'endTime': 0.08},
              'bad',
            ],
          },
        ],
      });
      expect(line.text, 'Keep me');
      expect(line.timeline, hasLength(1));
      expect(line.timeline!.single.phones, hasLength(1));
      expect(line.timeline!.single.phones!.single.phone, 'h');
      expect(line.timeline!.single.phones!.single.startTime, 0);
    });

    test('nested times do not rewrite line start or duration', () {
      final line = TranscriptLine.fromJson({
        'text': 'Cue',
        'start': 1000,
        'duration': 500,
        'timeline': [
          {'text': 'Cue', 'start': 0, 'duration': 9999},
        ],
      });
      expect(line.startMs, 1000);
      expect(line.durationMs, 500);
      expect(line.timeline!.single.startMs, 0);
      expect(line.timeline!.single.durationMs, 9999);
    });
  });

  group('identity vs equality', () {
    test('cueIdFor is unchanged when timeline words are added', () {
      const flat = TranscriptLine(
        text: 'Hello world',
        startMs: 2000,
        durationMs: 3000,
      );
      const nested = TranscriptLine(
        text: 'Hello world',
        startMs: 2000,
        durationMs: 3000,
        timeline: [
          TranscriptWord(text: 'Hello'),
          TranscriptWord(text: 'world'),
        ],
      );
      expect(cueIdFor(nested), cueIdFor(flat));
    });

    test('sourceKey is unchanged by timeline', () {
      const line = TranscriptLine(
        text: 'Hello',
        startMs: 0,
        durationMs: 100,
        sourceKey: 'fingerprint',
        timeline: [TranscriptWord(text: 'Hello')],
      );
      expect(line.sourceKey, 'fingerprint');
      expect(line.toJson()['sourceKey'], 'fingerprint');
    });

    test('different timeline words are not ==', () {
      const a = TranscriptLine(
        text: 'hi',
        startMs: 0,
        durationMs: 100,
        timeline: [TranscriptWord(text: 'hi')],
      );
      const b = TranscriptLine(
        text: 'hi',
        startMs: 0,
        durationMs: 100,
        timeline: [TranscriptWord(text: 'HI')],
      );
      expect(a, isNot(equals(b)));
    });
  });
}
