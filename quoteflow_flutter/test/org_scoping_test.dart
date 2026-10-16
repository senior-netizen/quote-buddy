import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/services/backup_service.dart';
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scoping_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    Hive.init(tempDir.path);
    storage = StorageService();
    await storage.init();
    docProvider = DocumentProvider(storage);
    clientProvider = ClientProvider(storage);
    orgProvider = OrganizationProvider(storage);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Future<QuoteflowDocument> makeDoc(String id, String number) =>
      docProvider.createDocument(
        type: DocumentType.quote,
        docNumber: number,
        issueDate: '2026-09-01',
        clientId: 'c',
        lineItems: [LineItem(description: 'S', quantity: 1, unitPrice: 10)],
        taxRate: 0,
        discount: 0,
      );

  test('documents and clients are scoped to the active organization',
      () async {
    final defaultOrgId = orgProvider.activeOrgId;
    await docProvider.createDocument(
      type: DocumentType.invoice,
      docNumber: 'INV-DEFAULT',
      issueDate: '2026-09-01',
      clientId: 'c-default',
      lineItems: [LineItem(description: 'S', quantity: 1, unitPrice: 10)],
      taxRate: 0,
      discount: 0,
    );
    await clientProvider.createClient(companyName: 'Default Co');

    // Create + switch to a second organization.
    final beta = await orgProvider.createOrganization('Beta Ltd');
    expect(beta.id, isNot(defaultOrgId));

    await docProvider.createDocument(
      type: DocumentType.invoice,
      docNumber: 'INV-BETA',
      issueDate: '2026-09-02',
      clientId: 'c-beta',
      lineItems: [LineItem(description: 'S', quantity: 1, unitPrice: 10)],
      taxRate: 0,
      discount: 0,
    );
    await clientProvider.createClient(companyName: 'Beta Co');

    // Active org is Beta: only Beta's data is visible.
    expect(docProvider.documents.map((d) => d.docNumber),
        containsAll(['INV-BETA']));
    expect(docProvider.documents.map((d) => d.docNumber),
        isNot(contains('INV-DEFAULT')));
    expect(clientProvider.clients.map((c) => c.companyName),
        containsAll(['Beta Co']));
    expect(clientProvider.clients.map((c) => c.companyName),
        isNot(contains('Default Co')));

    // Dashboard-style aggregates respect the scope too.
    expect(docProvider.invoicesCount, 1);
    expect(docProvider.invoiceValue, 10);

    // Show-all: everything across companies.
    docProvider.setShowAll(true);
    clientProvider.setShowAll(true);
    expect(docProvider.invoicesCount, 2);
    expect(docProvider.documents.map((d) => d.docNumber),
        containsAll(['INV-DEFAULT', 'INV-BETA']));
    expect(clientProvider.clients.length, 2);

    // Switch back: scoped again to the default org.
    docProvider.setShowAll(false);
    clientProvider.setShowAll(false);
    orgProvider.switchOrganization(defaultOrgId);
    expect(docProvider.documents.map((d) => d.docNumber),
        containsAll(['INV-DEFAULT']));
    expect(docProvider.documents.map((d) => d.docNumber),
        isNot(contains('INV-BETA')));
  });

  test('new documents stamp the active organization id', () async {
    final doc = await makeDoc('x', 'QT-X');
    expect(doc.orgId, orgProvider.activeOrgId);
    final client =
        await clientProvider.createClient(companyName: 'Stamped Co');
    expect(client.orgId, orgProvider.activeOrgId);
  });

  test('legacy records without orgId are backfilled on first init', () async {
    final dir2 = await Directory.systemTemp.createTemp('scoping_backfill');
    PathProviderPlatform.instance = _FakePathProvider(dir2.path);
    await Hive.deleteFromDisk();
    Hive.init(dir2.path);

    // Seed legacy records (no orgId) before the storage layer initializes.
    final docsBox = await Hive.openBox<QuoteflowDocument>('documents');
    await docsBox.put('legacy-doc', QuoteflowDocument(
      id: 'legacy-doc',
      docType: 'quote',
      docNumber: 'QT-LEGACY',
      issueDate: '2026-01-01',
      lineItems: [],
      taxRate: 0,
      discount: 0,
      subtotal: 0,
      taxAmount: 0,
      total: 0,
      clientId: 'c',
      createdAt: '2026-01-01',
    ));
    await docsBox.close();
    final clientsBox = await Hive.openBox<Client>('clients');
    await clientsBox.put('legacy-client', Client(
      id: 'legacy-client',
      companyName: 'Old Co',
    ));
    await clientsBox.close();

    final s2 = StorageService();
    await s2.init();
    expect(s2.getDocument('legacy-doc')!.orgId, s2.getActiveOrg().id);
    expect(s2.getClient('legacy-client')!.orgId, s2.getActiveOrg().id);
  });

  test('branding preset export/parse round-trip', () {
    final org = Organization(
      id: 'x',
      name: 'Acme',
      logoUrl: 'data:image/png;base64,AAAA',
      pdfTheme: 'bold',
      logoPosition: 'right',
      logoSize: 44,
      bankName: 'CBZ',
    );
    final backup = BackupService(storage);
    final json = backup.exportOrgPreset(org);
    final parsed = backup.parseOrgPreset(json);
    expect(parsed, isNotNull);
    expect(parsed!.name, 'Acme');
    expect(parsed.pdfTheme, 'bold');
    expect(parsed.logoPosition, 'right');
    expect(parsed.logoSize, 44);
    expect(parsed.logoUrl, 'data:image/png;base64,AAAA');
    expect(parsed.bankName, 'CBZ');

    // Rejects files that are not branding presets.
    expect(backup.parseOrgPreset('not json'), isNull);
    expect(backup.parseOrgPreset('{"organization": {"name":"x"}}'), isNull);
  });
}