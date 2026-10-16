import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/backup_service.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/utils/share_origin.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mobile-recovery');
    PathProviderPlatform.instance = _Paths(directory.path);
    storage = StorageService();
    await storage.init();
  });
  tearDown(() async {
    await storage.close();
    await directory.delete(recursive: true);
  });
  QuoteflowDocument doc(String id, String org) => QuoteflowDocument(
    id: id,
    orgId: org,
    docType: 'invoice',
    docNumber: id,
    issueDate: '2026-10-16',
    createdAt: '2026-10-16',
    clientId: 'client',
    lineItems: [],
    taxRate: 0,
    discount: 0,
    subtotal: 10,
    taxAmount: 0,
    total: 10,
  );
  test(
    'multi-business backup restores every business and active selection',
    () async {
      await storage.saveActiveOrg(
        Organization(id: 'alpha', name: 'Alpha', currency: 'USD'),
      );
      await storage.saveDocument(doc('invoice-a', 'alpha'));
      await storage.saveActiveOrg(
        Organization(id: 'beta', name: 'Beta', currency: 'ZWG'),
      );
      await storage.saveDocument(doc('invoice-b', 'beta'));
      final exported = BackupService(storage).exportJson();
      await storage.deleteOrg('alpha');
      await storage.deleteOrg('beta');
      final result = await BackupService(storage).importFromJson(exported);
      expect(result.success, isTrue);
      expect(
        storage.listOrgs().map((o) => o.id),
        containsAll(['alpha', 'beta']),
      );
      expect(storage.getActiveOrg().id, 'beta');
      expect(storage.getDocument('invoice-a')!.orgId, 'alpha');
      expect(
        storage.listOrgs().singleWhere((o) => o.id == 'beta').currency,
        'ZWG',
      );
    },
  );
  for (final status in ['fiscalised', 'pending']) {
    test('backup cannot overwrite a $status fiscal document', () async {
      final org = storage.getActiveOrg().id;
      final current = doc('protected', org)..fiscalStatus = status;
      await storage.saveDocument(current);
      final stale = doc('protected', org)..total = 999;
      final result = await BackupService(storage).importFromJson(
        jsonEncode({
          'documents': [stale.toJson()],
        }),
      );
      expect(result.success, isTrue);
      expect(result.recordsSkipped, 1);
      expect(storage.getDocument('protected')!.total, 10);
      expect(storage.getDocument('protected')!.fiscalStatus, status);
    });
  }
  test(
    'ownership collisions are skipped and malformed collections change nothing',
    () async {
      final org = storage.getActiveOrg().id;
      await storage.saveActiveOrg(Organization(id: 'other', name: 'Other'));
      await storage.saveClient(
        Client(id: 'client', companyName: 'Original', orgId: org),
      );
      final result = await BackupService(storage).importFromJson(
        jsonEncode({
          'clients': [
            Client(
              id: 'client',
              companyName: 'Wrong owner',
              orgId: 'other',
            ).toJson(),
          ],
        }),
      );
      expect(result.recordsSkipped, 1);
      expect(storage.getClient('client')!.companyName, 'Original');
      expect(
        (await BackupService(storage).importFromJson(
          jsonEncode({
            'documents': {},
            'organization': Organization(id: 'new', name: 'New').toJson(),
          }),
        )).success,
        isFalse,
      );
      expect(storage.listOrgs().map((o) => o.id), isNot(contains('new')));
    },
  );
  test(
    'legacy records without ownership inherit the restored legacy business',
    () async {
      final legacy = doc('legacy', 'old').toJson()..remove('org_id');
      final result = await BackupService(storage).importFromJson(
        jsonEncode({
          'organization': Organization(id: 'old', name: 'Legacy').toJson(),
          'documents': [legacy],
        }),
      );
      expect(result.success, isTrue);
      expect(storage.getDocument('legacy')!.orgId, 'old');
    },
  );
  testWidgets('share-sheet anchor is nonempty on iPad-sized layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                final anchor = shareOrigin(context);
                expect(anchor.width, greaterThan(0));
                expect(anchor.height, greaterThan(0));
              },
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
  });
}
