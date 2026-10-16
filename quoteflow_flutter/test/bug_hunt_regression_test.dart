import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/services/zimra/zimra.dart';
import 'package:quoteflow/services/tax_engine.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

Map<String, dynamic> _wallet() => {
  'businessTin': '2000000001',
  'mode': 'live',
  'available': 20,
  'deviceIds': [123],
  'payments': [],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('disconnect invalidates an unfinished business connection', () async {
    final response = Completer<Map<String, dynamic>>();
    final billing = BillingProvider(
      post: (path, body, {token}) => response.future,
    );
    addTearDown(billing.dispose);
    final connecting = billing.connect('2000000001', 'private-dummy-code');
    billing.disconnect('2000000001');
    response.complete(_wallet());
    expect(await connecting, isFalse);
    expect(billing.wallet('2000000001'), isNull);
  });

  test('a cached production transport cannot send after disconnect', () async {
    var forwarded = 0;
    final billing = BillingProvider(
      post: (path, body, {token}) async {
        if (path.endsWith('/balance')) return _wallet();
        forwarded++;
        return {'statusCode': 200, 'rawBody': '{}'};
      },
    );
    addTearDown(billing.dispose);
    await billing.connect('2000000001', 'private-dummy-code');
    final transport = billing.productionTransport(
      const ZimraDeviceIdentity(deviceId: 123, serialNumber: 'AUDIT'),
      const ZimraCredentials(privateKeyPem: 'dummy', certificatePem: 'dummy'),
    );
    billing.disconnect('2000000001');
    final response = await transport.get('/Device/v1/123/GetStatus');
    expect(response.statusCode, 401);
    expect(forwarded, 0);
  });

  group('document financial integrity', () {
    late Directory directory;
    late StorageService storage;
    late DocumentProvider documents;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('audit-financial');
      PathProviderPlatform.instance = _Paths(directory.path);
      storage = StorageService();
      await storage.init();
      await storage.saveActiveOrg(
        Organization(id: 'owner-a', name: 'Business A')..taxEnabled = false,
      );
      documents = DocumentProvider(storage);
    });
    tearDown(() async {
      documents.dispose();
      await storage.close();
      await directory.delete(recursive: true);
    });
    Future<QuoteflowDocument> create() => documents.createDocumentV2(
      type: DocumentType.quote,
      docNumber: 'QT-AUDIT-1',
      issueDate: '2026-10-15',
      clientId: 'customer-a',
      lineItems: [LineItem(description: 'Service', quantity: 1, unitPrice: 10)],
      discount: 0,
    );

    for (final state in ['fiscalised', 'pending']) {
      test(
        'a $state fiscal document cannot have its financial content edited',
        () async {
          final saved = await create();
          saved.docType = 'invoice';
          saved.fiscalStatus = state;
          await documents.saveFiscalisation(saved);
          final edited = QuoteflowDocument.fromJson(saved.toJson());
          edited.fiscalStatus =
              null; // Clearing the submitted flag must not bypass the lock.
          edited.lineItems.single.unitPrice = 100;
          await expectLater(documents.updateDocument(edited), throwsStateError);
          expect(
            documents.getDocument(saved.id)!.lineItems.single.unitPrice,
            10,
          );
        },
      );
    }

    test('editing a non-tax quotation recomputes its saved total', () async {
      final saved = await create();
      final edited = QuoteflowDocument.fromJson(saved.toJson());
      edited.lineItems.single.unitPrice = 100;
      await documents.updateDocument(edited);
      expect(documents.getDocument(saved.id)!.subtotal, 100);
      expect(documents.getDocument(saved.id)!.total, 100);
    });
    test(
      'another active business cannot change the quotation tax profile',
      () async {
        final saved = await create();
        final other = Organization(id: 'owner-b', name: 'Business B')
          ..taxEnabled = true
          ..taxDefinitions = [
            const TaxDefinition(
              id: 'vat',
              name: 'VAT',
              rate: 15.5,
              type: TaxTreatment.standard,
              isDefault: true,
            ),
          ];
        await storage.saveActiveOrg(other);
        final edited = QuoteflowDocument.fromJson(saved.toJson());
        edited.lineItems.single.unitPrice = 100;
        await documents.updateDocument(edited);
        expect(documents.getDocument(saved.id)!.orgId, 'owner-a');
        expect(documents.getDocument(saved.id)!.taxAmount, 0);
        expect(documents.getDocument(saved.id)!.total, 100);
      },
    );
  });
}
