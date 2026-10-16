import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:quoteflow/models/adapters.dart';
import 'package:quoteflow/models/organization.dart';
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orgs_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    Hive.init(tempDir.path);
    registerAdapters();
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('seeds a default organization when empty', () {
    expect(storage.listOrgs().length, 1);
    expect(storage.getActiveOrg().name, 'Your Company');
  });

  test('multiple organizations: switch, save and activate', () async {
    final acme = Organization(
      id: 'org-acme',
      name: 'Acme',
      pdfTheme: 'bold',
      logoPosition: 'right',
      logoSize: 48,
    );
    final beta = Organization(
      id: 'org-beta',
      name: 'Beta Ltd',
      pdfTheme: 'elegant',
    );

    await storage.saveActiveOrg(acme);
    expect(storage.getActiveOrg().id, 'org-acme');

    await storage.saveActiveOrg(beta);
    expect(storage.getActiveOrg().id, 'org-beta');
    expect(storage.listOrgs().length, 3); // default + acme + beta

    await storage.switchOrg('org-acme');
    expect(storage.getActiveOrg().id, 'org-acme');
    expect(storage.getActiveOrg().pdfTheme, 'bold');
    expect(storage.getActiveOrg().logoPosition, 'right');
    expect(storage.getActiveOrg().logoSize, 48);

    // Active org settings are independent per organization.
    await storage.saveActiveOrg(
      Organization(
        id: 'org-acme',
        name: 'Acme',
        pdfTheme: 'minimal',
        logoPosition: 'left',
      ),
    );
    expect(storage.getActiveOrg().pdfTheme, 'minimal');
    await storage.switchOrg('org-beta');
    expect(storage.getActiveOrg().pdfTheme, 'elegant');
  });

  test('deleting the active org falls back to another', () async {
    await storage.saveActiveOrg(Organization(id: 'a', name: 'Alpha'));
    await storage.saveActiveOrg(Organization(id: 'b', name: 'Beta'));
    expect(storage.getActiveOrg().id, 'b');

    final next = await storage.deleteOrg('b');
    expect(next, isNotNull);
    expect(storage.getActiveOrg().id, 'a');

    final next2 = await storage.deleteOrg('a');
    // The seeded default org is still there and becomes active.
    expect(next2, isNotNull);
    expect(storage.getActiveOrg().name, 'Your Company');
  });
}