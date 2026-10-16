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
}

// Serialize historical records independently of the production writer. This
// adapter is installed only while creating a fixture, never while reading it.
class _FixtureOrganizationAdapter extends TypeAdapter<Organization> {
  _FixtureOrganizationAdapter(this.fieldCount, {this.malformedTail = false});

  final int fieldCount;
  final bool malformedTail;

  @override
  final int typeId = 3;

  @override
  Organization read(BinaryReader reader) =>
      throw UnsupportedError('Fixtures must use the production reader');

  @override
  void write(BinaryWriter writer, Organization obj) {
    final values = <dynamic>[
      obj.id,
      obj.name,
      obj.shortName,
      obj.logoUrl,
      obj.emails,
      obj.website,
      obj.registration,
      obj.tin,
      obj.duns,
      obj.praz,
      obj.currency,
      obj.defaultTaxRate,
      obj.address,
      obj.phone,
      obj.paymentInstructions,
      obj.pdfTheme,
      obj.city,
      obj.state,
      obj.postalCode,
      obj.country,
      obj.vatNumber,
      obj.bankAccountName,
      obj.bankName,
      obj.bankBranch,
      obj.bankAccountNumber,
      obj.bankIban,
      obj.bankSwift,
      obj.defaultPaymentTerms,
      obj.logoPosition,
      obj.tableStyle,
      obj.logoSize,
    ];
    // The affected app declared 28 fields but wrote 31, with an extra byte 31
    // immediately before the field-27 key.
    writer.writeByte(malformedTail ? 28 : fieldCount);
    for (var field = 0; field < fieldCount; field++) {
      if (malformedTail && field == 27) writer.writeByte(31);
      writer.writeByte(field);
      writer.write(values[field]);
    }
  }
}

Organization _completeOrganization() => Organization(
  id: 'company-acme',
  name: 'Acme Test Company',
  shortName: 'Acme',
  logoUrl: 'data:image/png;base64,dGVzdA==',
  emails: ['accounts@example.test', 'sales@example.test'],
  website: 'https://example.test',
  registration: 'REG-123',
  tin: 'TIN-456',
  duns: 'DUNS-789',
  praz: 'PRAZ-123',
  currency: 'ZAR',
  defaultTaxRate: 12.5,
  address: '42 Test Street',
  phone: '+263000000000',
  paymentInstructions: 'Use the invoice number as the reference.',
  pdfTheme: 'elegant',
  city: 'Harare',
  state: 'Harare Province',
  postalCode: 'TEST-001',
  country: 'Zimbabwe',
  vatNumber: 'VAT-456',
  bankAccountName: 'Acme Test Company',
  bankName: 'Test Bank',
  bankBranch: 'Test Branch',
  bankAccountNumber: 'TEST-ACCOUNT-123',
  bankIban: 'TEST-IBAN-456',
  bankSwift: 'TEST-SWIFT-789',
  defaultPaymentTerms: 30,
  logoPosition: 'right',
  tableStyle: 'bordered',
  logoSize: 48.5,
);

Future<void> _writeFixture(
  _FixtureOrganizationAdapter adapter,
  List<Organization> organizations,
) async {
  Hive.registerAdapter<Organization>(adapter, override: true);
  try {
    final box = await Hive.openBox<Organization>('organization');
    for (final organization in organizations) {
      await box.put(organization.id, organization);
    }
    await box.flush();
  } finally {
    await Hive.close();
    Hive.registerAdapter<Organization>(OrganizationAdapter(), override: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'organization_persistence_',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    Hive.init(tempDir.path);
    registerAdapters();
    Hive.registerAdapter<Organization>(OrganizationAdapter(), override: true);
  });

  tearDown(() async {
    await Hive.close();
    Hive.registerAdapter<Organization>(OrganizationAdapter(), override: true);
    PathProviderPlatform.instance = originalPathProvider;
    await tempDir.delete(recursive: true);
  });

  test(
    'saved company and active selection survive a full storage relaunch',
    () async {
      final company = _completeOrganization();
      final storage = StorageService();
      await storage.init();
      await storage.saveActiveOrg(company);
      await storage.close();

      // Reopening is essential: an immediate get() only tests Hive's memory cache.
      final relaunchedStorage = StorageService();
      await relaunchedStorage.init();

      expect(relaunchedStorage.getActiveOrg().toJson(), company.toJson());
      expect(relaunchedStorage.listOrgs(), hasLength(2));
      expect(
        relaunchedStorage
            .listOrgs()
            .singleWhere((org) => org.id == 'default')
            .toJson(),
        Organization.defaultOrg().toJson(),
      );
    },
  );

  test(
    'valid legacy 28-field records reopen with newer fields unset',
    () async {
      final company = _completeOrganization();
      await _writeFixture(_FixtureOrganizationAdapter(28), [company]);

      final box = await Hive.openBox<Organization>('organization');

      expect(box.get(company.id)?.toJson(), {
        ...company.toJson(),
        'logo_position': null,
        'table_style': null,
        'logo_size': null,
      });
    },
  );

  test(
    'valid legacy 16-field records reopen with later fields unset',
    () async {
      final company = _completeOrganization();
      await _writeFixture(_FixtureOrganizationAdapter(16), [company]);

      final box = await Hive.openBox<Organization>('organization');

      expect(box.get(company.id)?.toJson(), {
        ...company.toJson(),
        'city': null,
        'state': null,
        'postal_code': null,
        'country': null,
        'vat_number': null,
        'bank_account_name': null,
        'bank_name': null,
        'bank_branch': null,
        'bank_account_number': null,
        'bank_iban': null,
        'bank_swift': null,
        'default_payment_terms': null,
        'logo_position': null,
        'table_style': null,
        'logo_size': null,
      });
    },
  );

  test(
    'affected writer records recover every field after disk reopen',
    () async {
      final company = _completeOrganization();
      final defaultCompany = Organization.defaultOrg();
      final mixedNulls = Organization(
        id: 'mixed-null-fields',
        name: 'Mixed Null Fields',
        logoPosition: 'right',
        logoSize: 24.5,
      );
      final companies = [company, defaultCompany, mixedNulls];
      await _writeFixture(
        _FixtureOrganizationAdapter(31, malformedTail: true),
        companies,
      );

      final box = await Hive.openBox<Organization>('organization');

      expect(box.length, companies.length);
      for (final expected in companies) {
        expect(box.get(expected.id)?.toJson(), expected.toJson());
      }
    },
  );

  test(
    'storage relaunch recovers affected records and can save them again',
    () async {
      final company = _completeOrganization();
      await _writeFixture(
        _FixtureOrganizationAdapter(31, malformedTail: true),
        [company],
      );

      final storage = StorageService();
      await storage.init();
      expect(storage.getActiveOrg().toJson(), company.toJson());
      await storage.saveActiveOrg(storage.getActiveOrg());
      await storage.close();

      final relaunchedStorage = StorageService();
      await relaunchedStorage.init();
      expect(relaunchedStorage.getActiveOrg().toJson(), company.toJson());
      expect(relaunchedStorage.listOrgs(), hasLength(1));
    },
  );
}
