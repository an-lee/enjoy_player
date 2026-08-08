/// Shared text normalization helpers.
library;

/// Cached regex matching runs of whitespace characters.
final RegExp whitespaceRunRegExp = RegExp(r'\s+');

/// Collapses whitespace runs into single spaces and trims the result.
String collapseWhitespace(String input) {
  return input.replaceAll(whitespaceRunRegExp, ' ').trim();
}
