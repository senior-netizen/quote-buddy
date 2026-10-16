// Tax engine + FDMS resolver tests (scenarios A–O of the flexible-tax
// redesign). No test hard-codes a taxID: FDMS IDs always come from the
// simulated GetConfig applicableTaxes tables below.
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/tax_engine.dart';
import 'package:quoteflow/services/tax_resolver.dart';
import 'package:quoteflow/services/zimra/zimra_models.dart';

Organization _org({bool taxEnabled = true, List<TaxDefinition>? defs}) {
  defs ??= [
    const TaxDefinition(
      id: 'std',
      name: 'VAT',
      rate: 15.5,
      type: TaxTreatment.standard,
      isDefault: true,
    ),
    const TaxDefinition(
      id: 'zero',
      name: 'Zero rated',
      rate: 0,
      type: TaxTreatment.zeroRated,
    ),
    const TaxDefinition(
      id: 'exempt',
      name: 'Exempt',
      type: TaxTreatment.exempt,
    ),
  ];
  final org = Organization(id: 'o1', name: 'Test Co')..taxDefinitions = defs;
  org.taxEnabled = taxEnabled;
  return org;
}

/// A realistic FDMS GetConfig table. IDs are arbitrary — resolved, never
/// assumed.
ZimraConfig _fdmsConfig({List<ZimraTax>? taxes}) => ZimraConfig(
  applicableTaxes:
      taxes ??
      [
        const ZimraTax(
          taxId: 101,
          taxCode: '15',
          taxName: 'Standard rate',
          taxPercent: 15.5,
        ),
        const ZimraTax(
          taxId: 102,
          taxCode: '0',
          taxName: 'Zero rated',
          taxPercent: 0,
        ),
        const ZimraTax(
          taxId: 103,
          taxCode: '',
          taxName: 'Exempt',
          taxPercent: 0,
          isExempt: true,
        ),
      ],
  qrUrl: 'https://verify.zimra.example/',
);

LineItem _line({
  String description = 'Item',
  double quantity = 1,
  double unitPrice = 2000,
  TaxTreatment? treatment,
}) => LineItem(
  description: description,
  quantity: quantity,
  unitPrice: unitPrice,
  taxTreatment: treatment == null ? null : taxTreatmentToString(treatment),
);

void main() {
  group('A — non-VAT business', () {
    test(r'$2,000 stays $2,000 — no tax, no fabricated VAT', () {
      final org = _org(taxEnabled: false);
      final t = computeTotalsV2(items: [_line()], org: org);
      expect(t.subtotal, 2000.0);
      expect(t.taxAmount, 0.0);
      expect(t.total, 2000.0);
      expect(t.hasTax, isFalse);
      // Legacy display rate is 0 — never 15.5.
      expect(t.effectiveRate, 0.0);
    });

    test('treatments on lines cannot re-introduce tax for a non-VAT org', () {
      final org = _org(taxEnabled: false);
      final t = computeTotalsV2(
        items: [
          _line(treatment: TaxTreatment.standard),
          _line(treatment: TaxTreatment.zeroRated),
        ],
        org: org,
      );
      expect(t.total, 4000.0);
      expect(t.taxAmount, 0.0);
    });
  });

  group('B — VAT-registered business', () {
    test('2000 at 15.5% = 310 → total 2310', () {
      final org = _org();
      final t = computeTotalsV2(items: [_line()], org: org);
      expect(t.subtotal, 2000.0);
      expect(t.taxAmount, 310.0);
      expect(t.total, 2310.0);
      expect(t.effectiveRate, 15.5);
    });

    test('a non-default configured rate is honoured (e.g. 14.5%)', () {
      final org = _org(
        defs: [
          const TaxDefinition(
            id: 'std2',
            name: 'VAT',
            rate: 14.5,
            type: TaxTreatment.standard,
            isDefault: true,
          ),
        ],
      );
      final t = computeTotalsV2(items: [_line()], org: org);
      expect(t.taxAmount, closeTo(290.0, 0.01));
      expect(t.total, closeTo(2290.0, 0.01));
    });
  });

  group('C — mixed treatments on one invoice', () {
    test('each line taxed independently, discounts shared proportionally', () {
      final org = _org();
      final t = computeTotalsV2(
        items: [
          _line(
            description: 'A',
            unitPrice: 1000,
            treatment: TaxTreatment.standard,
          ),
          _line(
            description: 'B',
            unitPrice: 500,
            treatment: TaxTreatment.zeroRated,
          ),
          _line(
            description: 'C',
            unitPrice: 500,
            treatment: TaxTreatment.exempt,
          ),
        ],
        org: org,
        discount: 100,
      );
      expect(t.subtotal, 2000.0);
      // A: 1000 − 50 = 950 × 15.5% = 147.25. B & C: no tax.
      expect(t.lines[0].taxAmount, 147.25);
      expect(t.lines[1].taxAmount, 0.0);
      expect(t.lines[2].taxAmount, 0.0);
      expect(t.taxAmount, 147.25);
      expect(t.total, 2047.25);
    });
  });

  group('D — zero-rated item', () {
    test('0% tax but treatment preserved as zeroRated', () {
      final org = _org();
      final t = computeTotalsV2(
        items: [_line(treatment: TaxTreatment.zeroRated)],
        org: org,
      );
      expect(t.taxAmount, 0.0);
      expect(t.total, 2000.0);
      expect(t.lines.single.treatment, TaxTreatment.zeroRated);
      // Zero-rated resolves to a real 0% FDMS entry — NOT exempt.
      final res = resolveFdmsTax(
        treatment: TaxTreatment.zeroRated,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 102);
      expect(res.tax!.isExempt, isFalse);
    });
  });

  group('E — exempt item', () {
    test('no tax and resolves to the exempt FDMS entry', () {
      final org = _org();
      final t = computeTotalsV2(
        items: [_line(treatment: TaxTreatment.exempt)],
        org: org,
      );
      expect(t.taxAmount, 0.0);
      final res = resolveFdmsTax(
        treatment: TaxTreatment.exempt,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 103);
      expect(res.tax!.isExempt, isTrue);
    });
  });

  group('F — no-tax item', () {
    test('noTax lines never resolve to the 15.5% entry', () {
      final org = _org(taxEnabled: false);
      final t = computeTotalsV2(items: [_line()], org: org);
      expect(t.lines.single.treatment, TaxTreatment.noTax);
      expect(t.taxAmount, 0.0);
    });

    test('noTax can use an exempt fallback but not arbitrary VAT entries', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.noTax,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.isExempt, isTrue);
      // Without an exempt entry it is a hard stop.
      final res2 = resolveFdmsTax(
        treatment: TaxTreatment.noTax,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: [
          const ZimraTax(
            taxId: 9,
            taxCode: '',
            taxName: 'Only standard',
            taxPercent: 15.5,
          ),
        ],
      );
      expect(res2.ok, isFalse);
      expect(res2.problem, contains('No compatible ZIMRA tax configuration'));
    });
  });

  group('G — FDMS taxID resolution', () {
    test('standard resolves from config, never invented', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 101);
    });

    test('decimal-safe comparison groups 15.5 vs 15.499999', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.499999,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 101);
    });
  });

  group('H — missing FDMS mapping', () {
    test('unmatched rate is a hard stop naming the rate', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 20,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: _fdmsConfig().applicableTaxes,
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('20%'));
    });

    test('empty FDMS table is a hard stop', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: const [],
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('no applicable taxes'));
    });

    test('buildFiscalLines reports the missing mapping, never substitutes', () {
      final org = _org();
      final doc = QuoteflowDocument(
        id: 'd1',
        docType: 'invoice',
        docNumber: 'INV-1',
        issueDate: '2026-09-25',
        lineItems: [_line(unitPrice: 2000, treatment: TaxTreatment.standard)],
        taxRate: 15.5,
        discount: 0,
        subtotal: 2000,
        taxAmount: 310,
        total: 2310,
        clientId: 'c',
        createdAt: '2026-09-25',
      );
      final res = buildFiscalLines(
        doc: doc,
        config: _fdmsConfig(
          taxes: [
            // Config only carries an entry for a DIFFERENT rate.
            const ZimraTax(
              taxId: 55,
              taxCode: '',
              taxName: 'Tourism levy',
              taxPercent: 2,
            ),
          ],
        ),
        org: org,
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('15.5%'));
    });
  });

  group('I/J — expired and future tax definitions', () {
    final validTable = <ZimraTax>[
      const ZimraTax(
        taxId: 201,
        taxCode: '',
        taxName: 'Old 15.5%',
        taxPercent: 15.5,
        validFrom: '2024-01-01',
        validTill: '2026-01-01',
      ),
      const ZimraTax(
        taxId: 202,
        taxCode: '',
        taxName: 'New 15.5%',
        taxPercent: 15.5,
        validFrom: '2026-06-01',
      ),
    ];

    test('I: entry expired before the document date is not used', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        documentDate: DateTime(2026, 9, 25),
        applicableTaxes: validTable,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 202);
    });

    test('J: entry starting after the document date is not used', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        documentDate: DateTime(2025, 6, 1),
        applicableTaxes: validTable,
      );
      expect(res.ok, isTrue);
      expect(res.tax!.taxId, 201);
    });

    test('no valid entry on the date is a hard stop', () {
      final res = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        // Between the two windows — nothing valid.
        documentDate: DateTime(2026, 3, 15),
        applicableTaxes: validTable,
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('valid on'));
    });

    test('K: rate change over time — same treatment resolves to the '
        'entry valid on the document date', () {
      final history = <ZimraTax>[
        const ZimraTax(
          taxId: 301,
          taxCode: '',
          taxName: 'VAT 2025',
          taxPercent: 15,
          validFrom: '2025-01-01',
          validTill: '2025-12-31',
        ),
        const ZimraTax(
          taxId: 302,
          taxCode: '',
          taxName: 'VAT 2026',
          taxPercent: 15.5,
          validFrom: '2026-01-01',
        ),
      ];
      final old = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15,
        documentDate: DateTime(2025, 6, 1),
        applicableTaxes: history,
      );
      final updated = resolveFdmsTax(
        treatment: TaxTreatment.standard,
        rate: 15.5,
        documentDate: DateTime(2026, 6, 1),
        applicableTaxes: history,
      );
      expect(old.tax!.taxId, 301);
      expect(updated.tax!.taxId, 302);
    });
  });

  group('L — historical invoice retention', () {
    test('legacy lines with stored treatments are never re-rated', () {
      // A historical invoice stored with explicit treatments keeps them
      // even when the org default changes afterwards.
      final doc = QuoteflowDocument(
        id: 'h1',
        docType: 'invoice',
        docNumber: 'INV-OLD',
        issueDate: '2025-06-01',
        lineItems: [_line(unitPrice: 2000, treatment: TaxTreatment.standard)],
        taxRate: 15.5,
        discount: 0,
        subtotal: 2000,
        taxAmount: 310,
        total: 2310,
        clientId: 'c',
        createdAt: '2025-06-01',
      );
      // Org switches default to zero-rated (keeps the standard definition
      // — changing the DEFAULT never deletes configured treatments).
      final org2 = _org(
        defs: [
          const TaxDefinition(
            id: 'std',
            name: 'VAT',
            rate: 15.5,
            type: TaxTreatment.standard,
          ),
          const TaxDefinition(
            id: 'zero2',
            name: 'Zero rated',
            rate: 0,
            type: TaxTreatment.zeroRated,
            isDefault: true,
          ),
        ],
      );
      expect(
        lineTaxTreatment(doc.lineItems.first, org2),
        TaxTreatment.standard,
      );
      // Totals recompute identically from the stored treatment.
      final t = computeTotalsV2(items: doc.lineItems, org: org2);
      expect(t.taxAmount, 310.0);
      expect(t.total, 2310.0);
    });
  });

  group('M — organisation switching tax configuration', () {
    test('toggling tax off changes NEW documents, not historical totals', () {
      final orgVat = _org();
      final orgNoTax = _org(taxEnabled: false);

      // New document on the non-VAT profile: $2,000 total.
      final newT = computeTotalsV2(
        items: [_line(unitPrice: 2000)],
        org: orgNoTax,
      );
      expect(newT.total, 2000.0);

      // The VAT org's document still computes with VAT.
      final vatT = computeTotalsV2(
        items: [_line(unitPrice: 2000)],
        org: orgVat,
      );
      expect(vatT.total, 2310.0);
    });

    test(
      'default treatment changes flow to unassigned (legacy) lines only',
      () {
        final orgA = _org();
        final orgB = _org(
          defs: [
            const TaxDefinition(
              id: 'ex2',
              name: 'Exempt',
              type: TaxTreatment.exempt,
              isDefault: true,
            ),
          ],
        );
        final unassigned = _line(unitPrice: 100); // taxTreatment == null
        expect(lineTaxTreatment(unassigned, orgA), TaxTreatment.standard);
        expect(lineTaxTreatment(unassigned, orgB), TaxTreatment.exempt);
      },
    );
  });

  group('N/O — fiscal receipt totals match invoice totals', () {
    test('non-VAT invoice fiscalises to a receipt with the same total', () {
      final org = _org(taxEnabled: false);
      final doc = QuoteflowDocument(
        id: 'nv1',
        docType: 'invoice',
        docNumber: 'INV-NV',
        issueDate: '2026-09-25',
        lineItems: [
          _line(description: 'Consulting', unitPrice: 1200),
          _line(description: 'Setup', unitPrice: 800),
        ],
        taxRate: 0,
        discount: 0,
        subtotal: 2000,
        taxAmount: 0,
        total: 2000,
        clientId: 'c',
        createdAt: '2026-09-25',
      );
      final res = buildFiscalLines(doc: doc, config: _fdmsConfig(), org: org);
      expect(res.ok, isTrue);
      final totalCents = fiscalTotalCents(res.lines);
      // Receipt total (in cents) equals the invoice total exactly.
      expect(totalCents, 200000);
    });

    test('VAT invoice receipt total includes the resolved VAT', () {
      final org = _org();
      final doc = QuoteflowDocument(
        id: 'v1',
        docType: 'invoice',
        docNumber: 'INV-V',
        issueDate: '2026-09-25',
        lineItems: [_line(unitPrice: 2000, treatment: TaxTreatment.standard)],
        taxRate: 15.5,
        discount: 0,
        subtotal: 2000,
        taxAmount: 310,
        total: 2310,
        clientId: 'c',
        createdAt: '2026-09-25',
      );
      final res = buildFiscalLines(doc: doc, config: _fdmsConfig(), org: org);
      expect(res.ok, isTrue);
      expect(fiscalTotalCents(res.lines), 231000);
    });

    test('mixed-treatment invoice receipt total equals document total', () {
      final org = _org();
      final doc = QuoteflowDocument(
        id: 'm1',
        docType: 'invoice',
        docNumber: 'INV-M',
        issueDate: '2026-09-25',
        lineItems: [
          _line(
            description: 'A',
            unitPrice: 1000,
            treatment: TaxTreatment.standard,
          ),
          _line(
            description: 'B',
            unitPrice: 500,
            treatment: TaxTreatment.zeroRated,
          ),
          _line(
            description: 'C',
            unitPrice: 500,
            treatment: TaxTreatment.exempt,
          ),
        ],
        taxRate: 15.5,
        discount: 0,
        subtotal: 2000,
        taxAmount: 155,
        total: 2155,
        clientId: 'c',
        createdAt: '2026-09-25',
      );
      final res = buildFiscalLines(doc: doc, config: _fdmsConfig(), org: org);
      expect(res.ok, isTrue);
      // Lines: A@15.5% + B@0% + C@exempt → 1000×1.155 + 500 + 500.
      expect(fiscalTotalCents(res.lines), 215500);
    });
  });

  group('model round-trips', () {
    test('TaxDefinition JSON round-trips', () {
      const d = TaxDefinition(
        id: 'x',
        name: 'VAT',
        rate: 15.5,
        type: TaxTreatment.standard,
        isDefault: true,
        source: TaxSource.fdms,
        fdmsTaxId: 42,
        validFrom: '2026-01-01',
      );
      final back = TaxDefinition.fromJson(d.toJson());
      expect(back, d);
    });

    test('Organization JSON carries the tax profile', () {
      final org = _org()..defaultTaxTreatment = 'standard';
      final back = Organization.fromJson(org.toJson());
      expect(back.taxEnabled, isTrue);
      expect(back.taxDefinitions, org.taxDefinitions);
      expect(back.defaultTreatment, TaxTreatment.standard);
    });

    test('LineItem JSON carries the treatment; legacy JSON has none', () {
      final l = _line(treatment: TaxTreatment.zeroRated);
      final back = LineItem.fromJson(l.toJson());
      expect(back.taxTreatment, 'zero_rated');
      final legacy = LineItem.fromJson({
        'description': 'x',
        'quantity': 1,
        'unit_price': 5.0,
      });
      expect(legacy.taxTreatment, isNull);
    });
  });
}
