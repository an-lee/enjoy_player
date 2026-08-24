import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';

Finder findChromeIcon(EnjoyChromeGlyph glyph) {
  return find.byWidgetPredicate(
    (widget) => widget is EnjoyChromeIcon && widget.glyph == glyph,
    description: 'EnjoyChromeIcon($glyph)',
  );
}
