import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/payment_processor_option.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _harness({
  required PaymentProcessor processor,
  required bool selected,
  required bool enabled,
  VoidCallback? onSelected,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    locale: const Locale('en', 'US'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PaymentProcessorOption(
        processor: processor,
        selected: selected,
        enabled: enabled,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentProcessor (enum helpers)', () {
    test('apiValue uses the enum name', () {
      expect(PaymentProcessor.stripe.apiValue, 'stripe');
      expect(PaymentProcessor.mixin.apiValue, 'mixin');
    });

    test('fromJson resolves known + unknown + null values', () {
      expect(PaymentProcessor.fromJson('stripe'), PaymentProcessor.stripe);
      expect(PaymentProcessor.fromJson('MIXIN'), PaymentProcessor.mixin);
      expect(PaymentProcessor.fromJson('apple'), isNull);
      expect(PaymentProcessor.fromJson(null), isNull);
    });

    test('PaymentStatus.fromJson resolves known values', () {
      expect(PaymentStatus.fromJson('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromJson('SUCCEEDED'), PaymentStatus.succeeded);
      expect(PaymentStatus.fromJson('expired'), PaymentStatus.expired);
      expect(PaymentStatus.fromJson('garbage'), isNull);
      expect(PaymentStatus.fromJson(null), isNull);
    });
  });

  group('PaymentProcessorOption', () {
    testWidgets('renders Stripe title + four brand chips when unselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          processor: PaymentProcessor.stripe,
          selected: false,
          enabled: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stripe'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('WeChat'), findsOneWidget);
      expect(find.text('Alipay'), findsOneWidget);
      expect(find.text('Google Pay'), findsOneWidget);
      // Brand icons render as SvgPicture widgets.
      final svgCount = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .length;
      expect(svgCount, 4);
      expect(find.byIcon(Icons.radio_button_off_rounded), findsOneWidget);
    });

    testWidgets('renders Mixin title + six crypto chips', (tester) async {
      await tester.pumpWidget(
        _harness(
          processor: PaymentProcessor.mixin,
          selected: false,
          enabled: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cryptocurrency'), findsOneWidget);
      expect(find.text('USDT'), findsOneWidget);
      expect(find.text('USDC'), findsOneWidget);
      expect(find.text('BTC'), findsOneWidget);
      expect(find.text('ETH'), findsOneWidget);
      expect(find.text('Doge'), findsOneWidget);
      expect(find.text('and more'), findsOneWidget);
      // Five SVGs (one per crypto), the last entry has icon == null.
      final svgCount = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .length;
      expect(svgCount, 5);
    });

    testWidgets('selected=true swaps to the filled radio icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          processor: PaymentProcessor.stripe,
          selected: true,
          enabled: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off_rounded), findsNothing);
    });

    testWidgets('tapping an enabled option fires onSelected', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _harness(
          processor: PaymentProcessor.stripe,
          selected: false,
          enabled: true,
          onSelected: () => tapped++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('tapping a disabled option is a no-op', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _harness(
          processor: PaymentProcessor.mixin,
          selected: false,
          enabled: false,
          onSelected: () => tapped++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(tapped, 0);
    });
  });
}
