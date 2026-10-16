// Local taxes must never override or supplement GetConfig.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/tax_engine.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

ZimraTax _fdms(int id, double percent, {bool exempt = false}) => ZimraTax(
  taxId: id,
  taxCode: '',
  taxName: 'FDMS $id',
  taxPercent: percent,
  isExempt: exempt,
);

ZimraTax _manual(
  int id,
  double percent, {
  bool exempt = false,
  String name = 'Manual tax',
}) => ZimraTax(
  taxId: id,
  taxCode: '',
  taxName: name,
  taxPercent: percent,
  isExempt: exempt,
  isManual: true,
);

void main() {
  group('mergeTaxTables', () {
    test('empty manual table returns the FDMS list unchanged', () {
      final fdms = [_fdms(1, 15), _fdms(2, 0), _fdms(3, 0, exempt: true)];
      expect(mergeTaxTables(fdms, []), fdms);
    });

    test('empty FDMS table rejects manual entries', () {
      final manual = [_manual(101, 15)];
      expect(mergeTaxTables([], manual), isEmpty);
    });

    test('manual entries cannot fill gaps in the FDMS table', () {
      final merged = mergeTaxTables([_fdms(1, 15)], [_manual(101, 0)]);
      expect(merged.map((t) => t.taxId), [1]);
      expect(merged.single.isManual, isFalse);
    });

    test(
      'a manual entry cannot override the FDMS entry with the same taxID',
      () {
        final merged = mergeTaxTables(
          [_fdms(1, 16.5)],
          [_manual(1, 15, name: 'Corrected')],
        );
        expect(merged, hasLength(1));
        expect(merged.single.taxPercent, 16.5);
        expect(merged.single.taxName, 'FDMS 1');
        expect(merged.single.isManual, isFalse);
      },
    );

    test('a Refresh never loses FDMS entries that are not overridden', () {
      final merged = mergeTaxTables(
        [_fdms(1, 15), _fdms(2, 0)],
        [_manual(9, 10)],
      );
      expect(merged.map((t) => t.taxId), [1, 2]);
    });

    test('duplicate manual IDs are excluded', () {
      final merged = mergeTaxTables([], [_manual(5, 10), _manual(5, 14)]);
      expect(merged, isEmpty);
    });

    test('merged entries keep manual validity windows', () {
      final manual = [
        const ZimraTax(
          taxId: 7,
          taxCode: 'A',
          taxName: 'Windowed',
          taxPercent: 15,
          validFrom: '2026-01-01',
          validTill: '2026-12-31',
          isManual: true,
        ),
      ];
      final merged = mergeTaxTables([], manual);
      expect(merged, isEmpty);
    });
  });

  group('ZimraTax JSON round-trip with manual flag', () {
    test('isManual and validity windows survive a round-trip', () {
      const tax = ZimraTax(
        taxId: 42,
        taxCode: 'b',
        taxName: 'My VAT',
        taxPercent: 14.5,
        validFrom: '2026-01-01',
        isManual: true,
      );
      final back = ZimraTax.fromJson(tax.toJson());
      expect(back.taxId, 42);
      expect(back.taxCode, 'b');
      expect(back.taxName, 'My VAT');
      expect(back.taxPercent, 14.5);
      expect(back.validFrom, '2026-01-01');
      expect(back.isManual, isTrue);
    });

    test('FDMS-shaped wire input (taxID) parses with isManual false', () {
      final back = ZimraTax.fromJson({
        'taxID': 3,
        'taxName': 'Standard',
        'taxPercent': 15,
      });
      expect(back.taxId, 3);
      expect(back.isManual, isFalse);
    });
  });

  group('ZimraProvider manual tax persistence', () {
    late Directory tempDir;
    late Box box;
    late ZimraProvider provider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('manual-taxes-');
      Hive.init(tempDir.path);
      box = await Hive.openBox('zimra');
      await box.putAll({
        'zimra_identity': const ZimraDeviceIdentity(
          deviceId: 1,
          serialNumber: 'T',
        ).toJson(),
        'zimra_credentials': const ZimraCredentials(
          privateKeyPem: '',
          certificatePem: '',
        ).toJson(),
        'zimra_config': ZimraConfig(
          applicableTaxes: [_fdms(1, 15)],
          qrUrl: 'https://qr.example/',
        ).toJson(),
      });
      provider = ZimraProvider(box);
      await provider.init();
    });

    tearDown(() async {
      provider.dispose();
      await box.close();
      await tempDir.delete(recursive: true);
    });

    test('effectiveConfig retains only the FDMS config', () {
      expect(provider.config!.applicableTaxes, hasLength(1));
      final effective = provider.effectiveConfig!;
      expect(effective.qrUrl, 'https://qr.example/');
      expect(effective.applicableTaxes, hasLength(1));
    });

    test('setManualTaxes persists across a provider restart', () async {
      await provider.setManualTaxes([_manual(101, 14.5)]);

      final reopened = ZimraProvider(box);
      await reopened.init();
      addTearDown(reopened.dispose);

      expect(reopened.manualTaxes, hasLength(1));
      expect(reopened.manualTaxes.single.taxId, 101);
      expect(reopened.manualTaxes.single.isManual, isTrue);

      final effective = reopened.effectiveConfig!;
      expect(effective.applicableTaxes.map((t) => t.taxId), [1]);
    });

    test(
      'a manual entry with the same taxID cannot replace the FDMS entry',
      () async {
        await provider.setManualTaxes([_manual(1, 15.5, name: 'Portal VAT')]);

        final effective = provider.effectiveConfig!;
        expect(effective.applicableTaxes, hasLength(1));
        expect(effective.applicableTaxes.single.taxName, 'FDMS 1');
        expect(effective.applicableTaxes.single.taxPercent, 15);
      },
    );

    test('clearDevice removes the manual tax table', () async {
      await provider.setManualTaxes([_manual(101, 15)]);
      await provider.clearDevice();
      expect(provider.manualTaxes, isEmpty);

      final raw = box.get('zimra_manual_taxes');
      expect(raw, isNull);
    });
  });

  group('fiscalisation against a manual-only table', () {
    test('buildFiscalLines rejects user-recorded taxes', () {
      final config = ZimraConfig(
        applicableTaxes: [
          _manual(101, 15),
          _manual(102, 0, name: 'Zero'),
          _manual(103, 0, exempt: true, name: 'Exempt'),
        ],
        qrUrl: 'https://qr.example/',
      );
      final org = Organization(
        id: 'o',
        name: 'Org',
        taxEnabled: true,
        taxDefinitions: [
          TaxDefinition(
            id: 'std',
            name: 'Standard',
            type: TaxTreatment.standard,
            rate: 15,
            isDefault: true,
          ),
        ],
      );

      final doc = _doc();
      final result = buildFiscalLines(doc: doc, config: config, org: org);

      expect(result.ok, isFalse);
      expect(result.lines, isEmpty);
    });

    test('fiscalConfigProblem points at Settings when the table is empty', () {
      final problem = fiscalConfigProblem(
        const ZimraConfig(applicableTaxes: [], qrUrl: 'https://qr.example/'),
      );
      expect(problem, contains('Settings'));
      expect(problem, contains('ZIMRA FDMS'));
    });

    test('mixed treatments cannot use manual taxIDs', () {
      final config = ZimraConfig(
        applicableTaxes: [
          _manual(101, 15),
          _manual(102, 0, name: 'Zero'),
          _manual(103, 0, exempt: true, name: 'Exempt'),
        ],
        qrUrl: 'https://qr.example/',
      );
      final org = Organization(
        id: 'o',
        name: 'Org',
        taxEnabled: true,
        taxDefinitions: [
          TaxDefinition(
            id: 'std',
            name: 'Standard',
            type: TaxTreatment.standard,
            rate: 15,
          ),
          TaxDefinition(id: 'zero', name: 'Zero', type: TaxTreatment.zeroRated),
          TaxDefinition(
            id: 'exempt',
            name: 'Exempt',
            type: TaxTreatment.exempt,
          ),
        ],
      );

      final doc = _doc(
        lines: [
          LineItem(
            description: 'A',
            quantity: 1,
            unitPrice: 100,
            taxTreatment: 'standard',
          ),
          LineItem(
            description: 'B',
            quantity: 1,
            unitPrice: 50,
            taxTreatment: 'zero_rated',
          ),
          LineItem(
            description: 'C',
            quantity: 1,
            unitPrice: 20,
            taxTreatment: 'exempt',
          ),
        ],
      );
      final result = buildFiscalLines(doc: doc, config: config, org: org);

      expect(result.ok, isFalse);
      expect(result.lines, isEmpty);
    });
  });
}

QuoteflowDocument _doc({List<LineItem>? lines}) => QuoteflowDocument(
  id: 'd1',
  docType: 'invoice',
  docNumber: 'INV-001',
  issueDate: '2026-09-25',
  lineItems:
      lines ??
      [LineItem(description: 'Consulting', quantity: 2, unitPrice: 50)],
  taxRate: 0,
  discount: 0,
  subtotal: 0,
  taxAmount: 0,
  total: 0,
  clientId: 'c1',
  createdAt: '2026-09-25T10:00:00',
);
