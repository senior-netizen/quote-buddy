import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:quoteflow/models/adapters.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/services/calculations.dart';
import 'package:quoteflow/services/pdf_service.dart';
import 'package:quoteflow/models/document.dart';

void main() {
  late Directory tempDir;

  // Type adapters are global to the VM: register them exactly once.
  registerAdapters();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quoteflow_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('Organization full detail fields survive a Hive round-trip', () async {
    final box = await Hive.openBox<Organization>('orgs');

    final org = Organization(
      id: 'org-1',
      name: 'Acme Trading (Pvt) Ltd',
      shortName: 'Acme',
      emails: ['billing@acme.co.zw'],
      website: 'https://acme.co.zw',
      registration: '1234/2020',
      tin: 'TIN-998877',
      vatNumber: 'VAT-445566',
      duns: 'DUNS-000',
      praz: 'PRAZ-AB123',
      currency: 'USD',
      defaultTaxRate: 15,
      address: '12 Samora Machel Ave',
      city: 'Harare',
      state: 'Harare',
      postalCode: '00263',
      country: 'Zimbabwe',
      phone: '+263 242 700 000',
      paymentInstructions: 'Reference the invoice number on payment.',
      bankAccountName: 'Acme Trading',
      bankName: 'CBZ Bank',
      bankBranch: 'Harare Main',
      bankAccountNumber: '01234567890',
      bankIban: 'ZW99 0000 1234',
      bankSwift: 'CBZZZWHX',
      defaultPaymentTerms: 30,
      pdfTheme: 'elegant',
      logoPosition: 'right',
      tableStyle: 'bordered',
      logoSize: 48,
    );

    await box.put('active', org);
    final read = box.get('active')!;

    expect(read.name, 'Acme Trading (Pvt) Ltd');
    expect(read.city, 'Harare');
    expect(read.country, 'Zimbabwe');
    expect(read.vatNumber, 'VAT-445566');
    expect(read.bankName, 'CBZ Bank');
    expect(read.bankAccountNumber, '01234567890');
    expect(read.bankIban, 'ZW99 0000 1234');
    expect(read.bankSwift, 'CBZZZWHX');
    expect(read.defaultPaymentTerms, 30);
    expect(read.pdfTheme, 'elegant');
    expect(read.logoPosition, 'right');
    expect(read.tableStyle, 'bordered');
    expect(read.logoSize, 48);
    expect(read.emails, ['billing@acme.co.zw']);

    await box.close();
  });

  test('Organization.fromJson tolerates missing optional company fields',
      () {
    final org = Organization.fromJson({'id': 'a', 'name': 'B'});
    expect(org.city, isNull);
    expect(org.state, isNull);
    expect(org.postalCode, isNull);
    expect(org.country, isNull);
    expect(org.vatNumber, isNull);
    expect(org.bankName, isNull);
    expect(org.bankAccountNumber, isNull);
    expect(org.defaultPaymentTerms, isNull);
  });

  test('Organization JSON round-trip keeps all company detail fields', () {
    final org = Organization(
      id: 'org-2',
      name: 'Global Supplies',
      city: 'Nairobi',
      country: 'Kenya',
      vatNumber: 'KE-VAT-1',
      bankName: 'Equity Bank',
      bankAccountNumber: '123456',
      bankSwift: 'EQBLKENA',
      defaultPaymentTerms: 14,
      logoPosition: 'right',
      tableStyle: 'minimal',
      logoSize: 40,
    );
    final restored = Organization.fromJson(org.toJson());
    expect(restored.city, 'Nairobi');
    expect(restored.country, 'Kenya');
    expect(restored.vatNumber, 'KE-VAT-1');
    expect(restored.bankName, 'Equity Bank');
    expect(restored.bankSwift, 'EQBLKENA');
    expect(restored.defaultPaymentTerms, 14);
    expect(restored.logoPosition, 'right');
    expect(restored.tableStyle, 'minimal');
    expect(restored.logoSize, 40);
  });

  test('Organization.copyWith overrides PDF style and keeps everything else',
      () {
    final org = Organization(
      id: 'o1',
      name: 'Acme',
      city: 'Harare',
      bankName: 'CBZ',
      pdfTheme: 'classic',
      logoPosition: 'left',
      logoSize: 36,
    );
    final overridden = org.copyWith(
      pdfTheme: 'bold',
      logoPosition: 'right',
      tableStyle: 'bordered',
      logoSize: 52,
    );
    expect(overridden.pdfTheme, 'bold');
    expect(overridden.logoPosition, 'right');
    expect(overridden.tableStyle, 'bordered');
    expect(overridden.logoSize, 52);
    expect(overridden.name, 'Acme');
    expect(overridden.city, 'Harare');
    expect(overridden.bankName, 'CBZ');
    // Un-overridden fields keep the source values.
    expect(org.pdfTheme, 'classic');
    expect(org.logoPosition, 'left');
    expect(org.logoSize, 36);
  });

  test('effectiveTableStyle falls back to each theme default', () {
    expect(effectiveTableStyle('classic', null), 'outlined');
    expect(effectiveTableStyle('elegant', null), 'outlined');
    expect(effectiveTableStyle('modern', null), 'striped');
    expect(effectiveTableStyle('bold', null), 'striped');
    expect(effectiveTableStyle('fresh', null), 'striped');
    expect(effectiveTableStyle('minimal', null), 'minimal');
    // Explicit choice wins over the theme default.
    expect(effectiveTableStyle('minimal', 'bordered'), 'bordered');
    expect(effectiveTableStyle('modern', 'outlined'), 'outlined');
    // Unknown / 'auto' values keep the theme default.
    expect(effectiveTableStyle('bold', 'auto'), 'striped');
    expect(effectiveTableStyle('classic', 'nonsense'), 'outlined');
  });

  test('Totals math includes tax and discount', () {
    final items = [
      LineItem(description: 'Widget', quantity: 3, unitPrice: 100),
      LineItem(description: 'Shipping', quantity: 1, unitPrice: 50),
    ];
    final totals = computeTotals(items, 15, 25);
    expect(totals.subtotal, 350);
    expect(totals.taxAmount, 52.5);
    expect(totals.total, 377.5);
  });

  test('Money formats with non-default currencies', () {
    expect(formatMoney(1234.5, 'USD'), contains(r'$'));
    expect(formatMoney(1234.5, 'EUR'), contains('€'));
    expect(formatMoney(1234.5, 'ZWL'), contains('Z\$'));
  });

  test('Document signature fields survive a Hive round-trip', () async {
    final box = await Hive.openBox<QuoteflowDocument>('docs');

    final doc = QuoteflowDocument(
      id: 'doc-sig-1',
      docType: 'invoice',
      docNumber: 'INV-2026-001',
      issueDate: '2026-08-01',
      dueDate: '2026-08-15',
      lineItems: [
        LineItem(description: 'Consulting', quantity: 1, unitPrice: 250),
      ],
      taxRate: 15,
      discount: 0,
      subtotal: 250,
      taxAmount: 37.5,
      total: 287.5,
      clientId: 'client-1',
      createdAt: '2026-08-01T10:00:00.000',
      docStatus: 'sent',
      orgId: 'org-a',
      signatureData: 'data:image/png;base64,iVBORw0KGgo=',
      signedAt: '2026-08-02T09:30:00.000',
      pdfTheme: 'bold',
      logoPosition: 'right',
      tableStyle: 'bordered',
    );

    await box.put('active', doc);
    final read = box.get('active')!;
    expect(read.signatureData, 'data:image/png;base64,iVBORw0KGgo=');
    expect(read.signedAt, '2026-08-02T09:30:00.000');
    expect(read.pdfTheme, 'bold');
    expect(read.logoPosition, 'right');
    expect(read.tableStyle, 'bordered');
    expect(read.orgId, 'org-a');
    expect(read.docStatus, 'sent');
    await box.close();
  });

  test('Document JSON round-trip keeps the signature fields', () {
    final doc = QuoteflowDocument(
      id: 'doc-sig-2',
      docType: 'invoice',
      docNumber: 'INV-2026-002',
      issueDate: '2026-08-03',
      lineItems: [
        LineItem(description: 'Service', quantity: 2, unitPrice: 100),
      ],
      taxRate: 15,
      discount: 0,
      subtotal: 200,
      taxAmount: 30,
      total: 230,
      clientId: 'client-2',
      createdAt: '2026-08-03T10:00:00.000',
      docStatus: 'paid',
      signatureData: 'data:image/png;base64,AAAA',
      signedAt: '2026-08-04T08:00:00.000',
      pdfTheme: 'fresh',
      orgId: 'org-b',
      logoPosition: 'left',
      tableStyle: 'minimal',
    );

    final restored = QuoteflowDocument.fromJson(doc.toJson());
    expect(restored.signatureData, doc.signatureData);
    expect(restored.signedAt, doc.signedAt);
    expect(restored.pdfTheme, 'fresh');
    expect(restored.logoPosition, 'left');
    expect(restored.tableStyle, 'minimal');
    expect(restored.orgId, 'org-b');

    // Old records without signature/override keys deserialize to null.
    final legacy = QuoteflowDocument.fromJson({'id': 'legacy'});
    expect(legacy.signatureData, isNull);
    expect(legacy.signedAt, isNull);
    expect(legacy.pdfTheme, isNull);
    expect(legacy.logoPosition, isNull);
    expect(legacy.tableStyle, isNull);
    expect(legacy.orgId, isNull);
  });

  test('Client orgId survives a Hive round-trip', () async {
    final box = await Hive.openBox<Client>('clients');
    await box.put('c1', Client(
      id: 'c1',
      companyName: 'Acme',
      orgId: 'org-a',
    ));
    final read = box.get('c1')!;
    expect(read.orgId, 'org-a');
    final restored = Client.fromJson(read.toJson());
    expect(restored.orgId, 'org-a');
    await box.close();
  });
}