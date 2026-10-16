import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/screens/credits_screen.dart';
import 'package:quoteflow/screens/dashboard_screen.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/theme/app_theme.dart';
import 'package:quoteflow/widgets/customer_form.dart';
import 'package:quoteflow/widgets/document_form_screen.dart';
import 'package:quoteflow/widgets/reference_design.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FailingDocuments extends DocumentProvider {
  _FailingDocuments(StorageService storage) : super(storage);
  @override
  Future<void> updateDocument(QuoteflowDocument doc) async =>
      throw const FileSystemException('Simulated write failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdkRoot = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.parent.path;
    final fontRoot = '$sdkRoot/artifacts/material_fonts';
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'Ahem': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File('$fontRoot/${entry.value}');
      if (await file.exists()) {
        final loader = FontLoader(entry.key)
          ..addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
  });
  late Directory directory;
  late StorageService storage;
  late ClientProvider clients;
  late DocumentProvider documents;
  late OrganizationProvider organizations;
  late BillingProvider billing;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mobile-polish');
    PathProviderPlatform.instance = _Paths(directory.path);
    storage = StorageService();
    await storage.init();
    await storage.saveActiveOrg(
      Organization(
        id: 'review-business',
        name: 'Acacia Trading',
        tin: '2000000001',
      ),
    );
    clients = ClientProvider(storage);
    documents = DocumentProvider(storage);
    organizations = OrganizationProvider(storage);
    billing = BillingProvider(
      post: (path, body, {token}) async => {
        'businessTin': '2000000001',
        'mode': 'live',
        'available': 500,
        'used': 12,
        'purchased': 500,
        'reserved': 0,
        'deviceIds': [123],
        'payments': [],
      },
    );
    await billing.connect('2000000001', 'preview-only');
    await clients.saveCustomer(Client(id: '', companyName: 'Acacia Trading'));
  });
  tearDown(() async {
    clients.dispose();
    documents.dispose();
    organizations.dispose();
    billing.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Widget app(
    Widget page, {
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: clients),
      ChangeNotifierProvider.value(value: documents),
      ChangeNotifierProvider.value(value: organizations),
      ChangeNotifierProvider.value(value: billing),
    ],
    child: RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
          textTheme: (dark ? AppTheme.dark() : AppTheme.light()).textTheme
              .apply(fontFamily: 'Roboto'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: ReferenceBackdrop(child: child!),
        ),
        home: page,
      ),
    ),
  );

  testWidgets(
    'deleting a quotation line preserves remaining controller values',
    (tester) async {
      await tester.pumpWidget(app(const DocumentFormScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add row'));
      await tester.tap(find.text('Add row'));
      await tester.pumpAndSettle();
      final descriptions = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText == 'Description' ||
                w.decoration?.hintText == 'Item or service description'),
      );
      await tester.enterText(descriptions.first, 'First item');
      await tester.enterText(descriptions.last, 'Second item');
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.delete_outline).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Second item'), findsOneWidget);
      expect(find.text('First item'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quotation warns before discarding edits and keeps them on cancel',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DocumentFormScreen(),
                  ),
                ),
                child: const Text('Create quotation'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create quotation'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'QT-CHANGED');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('QT-CHANGED'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Create quotation'), findsOneWidget);
    },
  );

  testWidgets('invalid customer email is rejected without writing a customer', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: CustomerForm())));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display / Customer Name *'),
      'New customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'invalid',
    );
    await tester.tap(find.text('Save Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(clients.allClients.length, 1);
  });

  testWidgets(
    'quotation rejects zero quantity without changing the saved document',
    (tester) async {
      final doc = await tester.runAsync(
        () => documents.createDocumentV2(
          type: DocumentType.quote,
          discount: 0,
          docNumber: 'QT-VALIDATION',
          issueDate: '2026-10-15',
          clientId: clients.allClients.single.id,
          lineItems: [
            LineItem(description: 'Consulting', quantity: 1, unitPrice: 25),
          ],
        ),
      );
      await tester.pumpWidget(app(DocumentFormScreen(editDoc: doc)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Qty',
        ),
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Qty',
        ),
        '0',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Each quantity must be greater than zero'),
        findsOneWidget,
      );
      expect(documents.getDocument(doc!.id)!.lineItems.single.quantity, 1);
    },
  );

  testWidgets(
    'failed quotation writes retain edits and leave the saved document unchanged',
    (tester) async {
      documents.dispose();
      documents = _FailingDocuments(storage);
      final doc = await tester.runAsync(
        () => documents.createDocumentV2(
          type: DocumentType.quote,
          discount: 0,
          docNumber: 'QT-FAILURE',
          issueDate: '2026-10-15',
          clientId: clients.allClients.single.id,
          lineItems: [
            LineItem(
              description: 'Original service',
              quantity: 1,
              unitPrice: 25,
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(DocumentFormScreen(editDoc: doc)));
      await tester.pumpAndSettle();
      final description = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText == 'Description' ||
                w.decoration?.hintText == 'Item or service description'),
      );
      await tester.ensureVisible(description);
      await tester.enterText(description, 'Updated service');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save document. Your changes are still here. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Updated service'), findsOneWidget);
      expect(
        documents.getDocument(doc!.id)!.lineItems.single.description,
        'Original service',
      );
    },
  );

  for (final dark in [false, true]) {
    for (final width in [390.0, 320.0]) {
      testWidgets(
        'mobile forms render at $width in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final entry in <String, Widget>{
            'quotation': const DocumentFormScreen(),
            'customer': const Scaffold(body: CustomerForm()),
            'credits': const CreditsScreen(),
            'dashboard': const DashboardScreen(),
          }.entries) {
            final key = GlobalKey();
            await tester.pumpWidget(
              app(
                entry.value,
                dark: dark,
                scale: width == 320 ? 1.4 : 1,
                capture: key,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: entry.key);
            if (entry.key == 'credits') {
              await tester.scrollUntilVisible(
                find.text('EcoCash'),
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await Scrollable.ensureVisible(
                tester.element(find.text('EcoCash')),
                alignment: 0.15,
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: 'credit purchase methods',
              );
            }
            if (width == 390) {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory('tmp/mobile-review').create(recursive: true);
                await File(
                  'tmp/mobile-review/${entry.key}-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(data!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }
}
