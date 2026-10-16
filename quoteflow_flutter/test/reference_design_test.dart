import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/screens/launch_screen.dart';
import 'package:quoteflow/widgets/reference_design.dart';
import 'package:quoteflow/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'reference waves and launch screen paint in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => ReferenceBackdrop(child: child!),
            home: const Scaffold(body: Text('Workspace')),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const QuoteFlowLaunchScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('QuoteFlow'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('document preview thumbnails stay within their cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final style in ['classic', 'modern', 'minimal', 'bold'])
                ReferenceDocumentPreview(style: style, accent: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
