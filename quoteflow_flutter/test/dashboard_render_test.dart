import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/screens/dashboard_screen.dart';
import 'package:quoteflow/screens/documents/document_detail_screen.dart';
import 'package:quoteflow/services/storage.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;
  late DocumentProvider docProvider;
  late ClientProvider clientProvider;
  late OrganizationProvider orgProvider;
  late QuoteflowDocument createdDoc;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('render_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    Hive.init(tempDir.path);
    storage = StorageService();
    await storage.init();
    docProvider = DocumentProvider(storage);
    clientProvider = ClientProvider(storage);
    orgProvider = OrganizationProvider(storage);

    // Create the document in the real-async zone so Hive's file I/O
    // actually completes before the widget tree is pumped.
    createdDoc = await docProvider.createDocument(
      type: DocumentType.invoice,
      docNumber: 'INV-2026-0001',
      issueDate: DateTime.now().toIso8601String().substring(0, 10),
      clientId: 'c-none',
      lineItems: [
        LineItem(description: 'Service', quantity: 1, unitPrice: 250),
      ],
      taxRate: 15,
      discount: 0,
      status: 'draft',
    );
    expect(docProvider.allDocuments.length, 1);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Widget app(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: docProvider),
          ChangeNotifierProvider.value(value: clientProvider),
          ChangeNotifierProvider.value(value: orgProvider),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: child,
        ),
      );

  testWidgets('dashboard renders after creating a document', (tester) async {
    // Regression: the recent-document rows used an untyped `doc` parameter,
    // so `doc.type.shortLabel` became a dynamic call and extension getters
    // were never resolved — the whole overview threw and rendered blank as
    // soon as the first document existed.
    await tester.pumpWidget(app(const DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('INV-2026-0001'), findsWidgets,
        reason: 'new doc should appear on the dashboard');
    expect(tester.takeException(), isNull);
  });

  testWidgets('document detail renders for a freshly created document',
      (tester) async {
    await tester.pumpWidget(
        app(DocumentDetailScreen(documentId: createdDoc.id)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('INV-2026-0001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}