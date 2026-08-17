/// Familiar-form IPA mapping (ported from Enjoy `@enjoy/utils/ipa`).
///
/// Tokenizes concatenated eSpeak phone chunks and remaps uncommon phonemes
/// to teaching-friendly forms. UI-free; no Flutter imports.
library;

/// Consonant catalog used by stress-shift heuristics.
const Map<String, List<String>> kIpaConsonants = {
  'plosive': [
    'p',
    'b',
    't',
    'd',
    'ʈ',
    'ɖ',
    'c',
    'ɟ',
    'k',
    'g',
    'q',
    'ɢ',
    'ʔ',
    'ɡ',
  ],
  'nasal': ['m', 'ɱ', 'n', 'ɳ', 'ɲ', 'ŋ', 'ɴ', 'n̩'],
  'trill': ['ʙ', 'r', 'ʀ'],
  'tapOrFlap': ['ⱱ', 'ɾ', 'ɽ'],
  'fricative': [
    'ɸ',
    'β',
    'f',
    'v',
    'θ',
    'ð',
    's',
    'z',
    'ʃ',
    'ʒ',
    'ʂ',
    'ʐ',
    'ç',
    'ʝ',
    'x',
    'ɣ',
    'χ',
    'ʁ',
    'ħ',
    'ʕ',
    'h',
    'ɦ',
  ],
  'lateralFricative': ['ɬ', 'ɮ'],
  'affricate': ['tʃ', 'ʈʃ', 'dʒ'],
  'approximant': ['ʋ', 'ɹ', 'ɻ', 'j', 'ɰ', 'w'],
  'lateralApproximant': ['l', 'ɭ', 'ʎ', 'ʟ'],
};

/// Vowel catalog used by stress-shift heuristics.
const Map<String, List<String>> kIpaVowels = {
  'close': ['i', 'yɨ', 'ʉɯ', 'u', 'iː'],
  'closeOther': ['ɪ', 'ʏ', 'ʊ', 'ɨ', 'ᵻ'],
  'closeMid': ['e', 'ø', 'ɘ', 'ɵ', 'ɤ', 'o', 'ə', 'oː'],
  'openMid': ['ɛ', 'œ', 'ɜ', 'ɞ', 'ʌ', 'ɔ', 'ɜː', 'uː', 'ɔː', 'ɛː'],
  'open': ['æ', 'a', 'ɶ', 'ɐ', 'ɑ', 'ɒ', 'ɑː'],
  'rhotic': ['◌˞', 'ɚ', 'ɝ', 'ɹ̩'],
  'diphthongs': [
    'eɪ',
    'əʊ',
    'oʊ',
    'aɪ',
    'ɔɪ',
    'aʊ',
    'iə',
    'ɜr',
    'ɑr',
    'ɔr',
    'oʊr',
    'oːɹ',
    'ir',
    'ɪɹ',
    'ɔːɹ',
    'ɑːɹ',
    'ʊɹ',
    'ʊr',
    'ɛr',
    'ɛɹ',
    'əl',
    'aɪɚ',
    'aɪə',
  ],
};

/// Uncommon / language-specific phonemes → teaching-friendly forms.
/// Empty-string targets drop the phoneme.
const Map<String, String> kIpaMappings = {
  'p': 'p',
  'b': 'b',
  't': 't',
  'd': 'd',
  'ʈ': 't',
  'ɖ': 'd',
  'c': 'k',
  'ɟ': 'g',
  'k': 'k',
  'g': 'g',
  'q': 'k',
  'ɢ': 'g',
  'ʔ': 't',
  'ɡ': 'g',
  'm': 'm',
  'ɱ': 'm',
  'n': 'n',
  'ɳ': 'n',
  'ɲ': 'j',
  'ŋ': 'ŋ',
  'ɴ': 'ŋ',
  'n̩': 'n',
  'ʙ': 'r',
  'r': 'r',
  'ʀ': 'r',
  'ⱱ': '',
  'ɾ': 't',
  'ɽ': 'r',
  'ɸ': 'f',
  'β': 'v',
  'f': 'f',
  'v': 'v',
  'θ': 'θ',
  'ð': 'ð',
  's': 's',
  'z': 'z',
  'ʃ': 'ʃ',
  'ʒ': 'ʒ',
  'ʂ': 's',
  'ʐ': 'z',
  'ç': '',
  'ʝ': 'j',
  'x': 'k',
  'ɣ': 'g',
  'χ': 'h',
  'ʁ': 'r',
  'ħ': 'h',
  'ʕ': '',
  'h': 'h',
  'ɦ': 'h',
  'ɬ': '',
  'ɮ': '',
  'tʃ': 'tʃ',
  'ʈʃ': 'tʃ',
  'dʒ': 'dʒ',
  'ʋ': 'v',
  'ɹ': 'r',
  'ɻ': 'r',
  'j': 'j',
  'ɰ': 'w',
  'w': 'w',
  'l': 'l',
  'ɭ': 'l',
  'ʎ': 'j',
  'ʟ': 'l',
  'i': 'i',
  'yɨ': 'iː',
  'ʉɯ': 'uː',
  'u': 'uː',
  'iː': 'iː',
  'ɪ': 'ɪ',
  'ʏ': 'ɪ',
  'ʊ': 'ʊ',
  'ɨ': 'i',
  'ᵻ': 'i:',
  'e': 'e',
  'ø': 'e',
  'ɘ': 'ə',
  'ɵ': 'ə',
  'ɤ': 'ɑː',
  'o': 'o',
  'ə': 'ə',
  'oː': 'oː',
  'ɛ': 'e',
  'œ': 'æ',
  'ɜ': 'ɝ',
  'ɞ': 'əː',
  'ʌ': 'ʌ',
  'ɔ': 'ɔ',
  'ɜː': 'ɝː',
  'uː': 'uː',
  'ɔː': 'ɔː',
  'ɛː': 'e:',
  'eː': 'i:',
  'æ': 'æ',
  'a': 'ɑ',
  'ɶ': 'ɑ',
  'ɐ': 'ə',
  'ɑ': 'ɑ',
  'ɒ': 'ɑː',
  'ɑː': 'ɑː',
  '◌˞': '',
  'ɚ': 'ɚ',
  'ɝ': 'ɝ',
  'ɹ̩': 'r',
  'eɪ': 'eɪ',
  'əʊ': 'oʊ',
  'oʊ': 'oʊ',
  'aɪ': 'aɪ',
  'ɔɪ': 'ɔɪ',
  'aʊ': 'aʊ',
  'iə': 'iə',
  'ɜr': 'ɜr',
  'ɑr': 'ɑr',
  'ɔr': 'ɔr',
  'oʊr': 'oʊr',
  'oːɹ': 'ɔːr',
  'ir': 'ir',
  'ɪɹ': 'ɪr',
  'ɔːɹ': 'ɔːr',
  'ɑːɹ': 'ɑːr',
  'ʊɹ': 'ʊr',
  'ʊr': 'ʊr',
  'ɛr': 'er',
  'ɛɹ': 'er',
  'əl': 'əl',
  'aɪɚ': 'aɪ',
  'aɪə': 'aɪə',
  'ts': 'tz',
};

const _lengthMarks = {'ː', ':'};
const _stressMarks = {'ˈ', 'ˌ'};

List<String>? _phonemeKeysCache;
List<String>? _allConsonantsCache;
List<String>? _allVowelsCache;
Set<String>? _trillSet;
Set<String>? _approximantSet;
Set<String>? _lateralApproximantSet;

List<String> get _allConsonants {
  return _allConsonantsCache ??= kIpaConsonants.values
      .expand((e) => e)
      .toList(growable: false);
}

List<String> get _allVowels {
  return _allVowelsCache ??= kIpaVowels.values
      .expand((e) => e)
      .toList(growable: false);
}

List<String> get _phonemeKeys {
  if (_phonemeKeysCache != null) return _phonemeKeysCache!;
  final keys = <String>{
    ...kIpaMappings.keys,
    ..._allConsonants,
    ..._allVowels,
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  return _phonemeKeysCache = keys;
}

Set<String> get _trills => _trillSet ??= kIpaConsonants['trill']!.toSet();
Set<String> get _approximants =>
    _approximantSet ??= kIpaConsonants['approximant']!.toSet();
Set<String> get _lateralApproximants =>
    _lateralApproximantSet ??= kIpaConsonants['lateralApproximant']!.toSet();

bool _matchesCatalog(String value, List<String> catalog) {
  final clean = value.replaceAll(RegExp('[ˈˌ]'), '');
  for (final entry in catalog) {
    if (clean == entry || clean.startsWith(entry)) {
      // Prefer exact or prefix-with-optional-stress already stripped.
      if (clean == entry) return true;
    }
  }
  // Longest-first prefix match for diphthongs / affricates.
  final sorted = List<String>.from(catalog)
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final entry in sorted) {
    if (clean.startsWith(entry)) return true;
  }
  return false;
}

bool _isConsonantToken(String value) => _matchesCatalog(value, _allConsonants);

bool _isVowelToken(String value) => _matchesCatalog(value, _allVowels);

String? _matchPhonemeAt(String ipa, int index) {
  for (final key in _phonemeKeys) {
    if (ipa.startsWith(key, index)) return key;
  }
  return null;
}

/// Split a (possibly concatenated) IPA string into phoneme tokens.
List<String> tokenizeIpaPhonemes(String ipa) {
  final tokens = <String>[];
  var i = 0;
  while (i < ipa.length) {
    final ch = ipa[i];
    if (_stressMarks.contains(ch)) {
      var j = i + 1;
      while (j < ipa.length && _lengthMarks.contains(ipa[j])) {
        j++;
      }
      if (j >= ipa.length) {
        i++;
        continue;
      }
      final key = _matchPhonemeAt(ipa, j);
      if (key != null) {
        tokens.add('$ch$key');
        i = j + key.length;
      } else {
        tokens.add('$ch${ipa[j]}');
        i = j + 1;
      }
      continue;
    }

    if (_lengthMarks.contains(ch)) {
      i++;
      continue;
    }

    final key = _matchPhonemeAt(ipa, i);
    if (key != null) {
      tokens.add(key);
      i += key.length;
    } else {
      tokens.add(ch);
      i++;
    }
  }
  return tokens;
}

/// Map a single phoneme through [kIpaMappings].
String convertIpaToNormal(
  String ipa, {
  Map<String, String> mappings = kIpaMappings,
  bool marked = false,
}) {
  final markMatch = RegExp('[ˈˌ]').firstMatch(ipa);
  final mark = markMatch?.group(0);
  final cleanIpa = mark == null ? ipa : ipa.replaceFirst(mark, '');
  final converted = mappings[cleanIpa] ?? cleanIpa;
  if (mark != null && marked) return '$mark$converted';
  return converted;
}

/// Convert a word's phoneme list to familiar forms, shifting stress from a
/// marked vowel onto a preceding consonant when appropriate.
List<String> convertWordIpaToNormal(
  List<String> ipas, {
  Map<String, String> mappings = kIpaMappings,
}) {
  final converted = <String>[];
  for (var i = 0; i < ipas.length; i++) {
    final ipa = ipas[i];
    converted.add(convertIpaToNormal(ipa, mappings: mappings, marked: false));

    final isVowel = _isVowelToken(ipa);
    final markMatch = RegExp('[ˈˌ]').firstMatch(ipa);
    final mark = markMatch?.group(0);

    var j = i - 1;
    for (; j > 0 && j > i - 2; j--) {
      final cur = converted[j];
      if (_isConsonantToken(cur) &&
          !_trills.contains(cur) &&
          !_approximants.contains(cur) &&
          !_lateralApproximants.contains(cur)) {
        break;
      }
      if (_isConsonantToken(cur) && !_isConsonantToken(converted[j - 1])) {
        break;
      }
    }

    if (isVowel && mark != null) {
      if (j >= 0 &&
          j < converted.length &&
          converted[j].isNotEmpty &&
          _isConsonantToken(converted[j])) {
        converted[j] = '$mark${converted[j]}';
      } else {
        converted[i] = '$mark${converted[i]}';
      }
    }
  }
  return converted;
}

/// Join phone labels into a familiar IPA string for display.
/// Skips empty phones and DTW placeholders (`?`).
String formatPhonesAsFamiliarIpa(List<String> phones) {
  final filtered = [
    for (final s in phones)
      if (s.isNotEmpty && s != '?') s,
  ];
  if (filtered.isEmpty) return '';
  final tokens = filtered.expand(tokenizeIpaPhonemes).toList(growable: false);
  return convertWordIpaToNormal(tokens).where((s) => s.isNotEmpty).join();
}
