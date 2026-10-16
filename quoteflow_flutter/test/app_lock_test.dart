import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quoteflow/providers/settings_provider.dart';
import 'package:quoteflow/widgets/app_lock_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app lock preferences persist PIN, enabled and biometrics flags',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsProvider();
    await settings.init();

    expect(settings.appLockEnabled, isFalse);
    expect(settings.appLockPin, isNull);
    expect(settings.appLockBiometrics, isFalse);

    await settings.setAppLockPin('4829');
    await settings.setAppLockEnabled(true);
    await settings.setAppLockBiometrics(true);

    // A fresh provider over the same backing store must see the values.
    final reloaded = AppSettingsProvider();
    await reloaded.init();
    expect(reloaded.appLockEnabled, isTrue);
    expect(reloaded.appLockPin, '4829');
    expect(reloaded.appLockBiometrics, isTrue);

    await reloaded.setAppLockEnabled(false);
    final finalCheck = AppSettingsProvider();
    await finalCheck.init();
    expect(finalCheck.appLockEnabled, isFalse);
  });

  testWidgets('LockGate hides the app behind the PIN screen when enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsProvider();
    await settings.init();
    await settings.setAppLockPin('1234');
    await settings.setAppLockEnabled(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: settings)],
        child: MaterialApp(
          builder: (context, child) =>
              LockGate(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('SECRET APP CONTENT')),
        ),
      ),
    );
    await tester.pump();

    // Locked: the overlay is shown.
    expect(find.text('QuoteFlow is locked'), findsOneWidget);

    // Wrong PIN keeps the lock in place.
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pump();
    expect(find.text('QuoteFlow is locked'), findsOneWidget);
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);

    // Correct PIN dismisses the lock screen.
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pump();
    expect(find.text('QuoteFlow is locked'), findsNothing);
    expect(find.text('SECRET APP CONTENT'), findsOneWidget);
  });

  testWidgets('LockGate passes straight through when disabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsProvider();
    await settings.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: settings)],
        child: MaterialApp(
          builder: (context, child) =>
              LockGate(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('SECRET APP CONTENT')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('QuoteFlow is locked'), findsNothing);
    expect(find.text('SECRET APP CONTENT'), findsOneWidget);
  });
}
