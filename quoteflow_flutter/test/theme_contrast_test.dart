import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'field text remains readable in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: TextField(
                readOnly: true,
                decoration: InputDecoration(labelText: 'Model'),
              ),
            ),
          ),
        );
        final field = tester.widget<EditableText>(find.byType(EditableText));
        final background = Color.alphaBlend(
          theme.inputDecorationTheme.fillColor!,
          theme.colorScheme.surface,
        );
        expect(
          contrast(field.style.color!, background),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }

  test('dark action labels and primary badges have readable contrast', () {
    final theme = AppTheme.dark();
    final action = theme.textButtonTheme.style!.foregroundColor!.resolve({})!;
    expect(
      contrast(action, theme.colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('light accents support readable small text', () {
    for (final color in [
      AppColors.accent,
      AppColors.blue,
      AppColors.green,
      AppColors.teal,
      AppColors.red,
      AppColors.orange,
      AppColors.gray,
    ]) {
      expect(contrast(color, AppColors.background), greaterThanOrEqualTo(4.5));
    }
  });
}
