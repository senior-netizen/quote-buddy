import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:quoteflow/widgets/reference_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/screens/credits_screen.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/theme/app_theme.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdkRoot = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.parent.path;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'Ahem': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File(sdkRoot + '/artifacts/material_fonts/' + entry.value);
      if (await file.exists())
        await (FontLoader(
              entry.key,
            )..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b))))
            .load();
    }
  });
  ThemeData previewTheme(bool dark) {
    final base = dark ? AppTheme.dark() : AppTheme.light();
    final label = base.textTheme.labelLarge!.copyWith(fontFamily: 'Roboto');
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.textTheme.titleLarge!.copyWith(
          fontFamily: 'Roboto',
        ),
        toolbarTextStyle: label,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: base.textTheme.titleMedium!.copyWith(
          fontFamily: 'Roboto',
        ),
        subtitleTextStyle: base.textTheme.bodyMedium!.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(label),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(label),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(label),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    for (final narrow in [false, true]) {
      testWidgets(
        'credits hierarchy ${dark ? 'dark' : 'light'} ${narrow ? '320 large text' : '390'}',
        (tester) async {
          tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final storage = StorageService();
          late Directory temp;
          await tester.runAsync(() async {
            temp = await Directory.systemTemp.createTemp('credits-hierarchy-');
            PathProviderPlatform.instance = _Paths(temp.path);
            await storage.init();
            await storage.saveActiveOrg(
              Organization(
                id: 'business',
                name: 'SQUIRRELLABS TECHNOLOGIES (PRIVATE) LIMITED',
                tin: '2000000001',
              ),
            );
          });
          final orgs = OrganizationProvider(storage);
          final billing = BillingProvider(
            post: (path, body, {token}) async => {
              'businessTin': '2000000001',
              'mode': 'test',
              'available': 520,
              'used': 0,
              'reserved': 0,
              'purchased': 500,
              'deviceIds': [123],
              'payments': <dynamic>[],
            },
          );
          await billing.connect('2000000001', 'code');
          addTearDown(() async {
            billing.dispose();
            orgs.dispose();
            await storage.close();
            await temp.delete(recursive: true);
          });
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: billing),
                ChangeNotifierProvider.value(value: orgs),
              ],
              child: MaterialApp(
                theme: previewTheme(dark),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: const ReferenceBackdrop(child: CreditsScreen()),
                ),
              ),
            ),
          );
          final previousError = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            previousError?.call(details);
          };
          addTearDown(() => FlutterError.onError = previousError);
          await tester.pumpAndSettle();
          expect(find.text('Connected'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Available credits'),
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Available credits'), findsOneWidget);
          expect(find.text('520'), findsOneWidget);
          final scroll = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(
            find.text('View usage'),
            120,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('View usage'));
          await tester.pumpAndSettle();
          expect(find.text('Credit usage'), findsOneWidget);
          Navigator.of(tester.element(find.text('Credit usage'))).pop();
          await tester.pumpAndSettle();
          for (final label in [
            'Purchase credits',
            'Buy 500 credits — US\$5.00',
            'Test fiscalisation (demo)',
            'Recent activity',
            'About fiscalisation credits',
          ]) {
            await tester.scrollUntilVisible(
              find.text(label),
              140,
              scrollable: scroll,
            );
            await tester.pumpAndSettle();
            expect(find.text(label), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          if (!narrow) {
            tester.view.physicalSize = const Size(390, 2400);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Connected'),
              -300,
              scrollable: scroll,
            );
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('build/visual-checks');
              await dir.create(recursive: true);
              await File(
                dir.path +
                    '/credits-hierarchy-' +
                    (dark ? 'dark' : 'light') +
                    '.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
