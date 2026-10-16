// Document ↔ FDMS mapping and fiscal-state persistence tests.
//
// Covers: tax/discount mapping, receipt types, credit/debit note reference
// to the original fiscal document, pending (offline) records, and the rule
// that only a successful FDMS answer may mark a document fiscalised.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/tax_engine.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

const _config = ZimraConfig(
  qrUrl: 'https://verify.zimra.example/',
  applicableTaxes: [
    ZimraTax(taxId: 101, taxCode: '15', taxName: '15%', taxPercent: 15),
    ZimraTax(taxId: 102, taxCode: '0', taxName: '0%', taxPercent: 0),
    ZimraTax(
      taxId: 103,
      taxCode: '',
      taxName: 'exempt',
      taxPercent: 0,
      isExempt: true,
    ),
  ],
);

QuoteflowDocument _doc({
  String docType = 'invoice',
  double taxRate = 15,
  double discount = 0,
  List<LineItem>? lineItems,
  String? convertedFrom,
}) => QuoteflowDocument(
  id: 'doc-1',
  docType: docType,
  docNumber: docType == 'invoice' ? 'INV-001' : 'CN-001',
  issueDate: '2026-09-25',
  lineItems:
      lineItems ?? [LineItem(description: 'Consulting', quantity: 2, unitPrice: 50)],
  taxRate: taxRate,
  discount: discount,
  subtotal: 100,
  taxAmount: 15,
  total: 105,
  clientId: 'client-1',
  createdAt: '2026-09-25T10:00:00',
  convertedFrom: convertedFrom,
);

FiscalisedReceipt _result(Map<String, dynamic> payload, {int receiptId = 501}) =>
    FiscalisedReceipt(
      receipt: payload,
      response: FiscalisedReceiptResponse(
        receiptId: receiptId,
        operationId: '0HMQCKLK5B38G:00000006',
      ),
    );

/// Organisation tax profile matching the FDMS tax table above (15% here
/// — the rate comes from the org config, resolved against taxID 101).
Organization _org({bool withZero = true}) {
  final org = Organization(id: 'o1', name: 'Test Co')
    ..taxDefinitions = [
      const TaxDefinition(
        id: 'std',
        name: 'VAT',
        rate: 15,
        type: TaxTreatment.standard,
        isDefault: true,
      ),
      if (withZero)
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
  org.taxEnabled = true;
  return org;
}

void main() {
  group('document → receipt line mapping', () {
    test('tax treatment resolves against the FDMS tax table', () {
      final res = buildFiscalLines(
        doc: _doc(lineItems: [
          LineItem(
            description: 'Consulting',
            quantity: 2,
            unitPrice: 50,
            taxTreatment: 'standard',
          ),
        ]),
        config: _config,
        org: _org(),
      );
      expect(res.ok, isTrue);
      expect(res.lines, hasLength(1));
      expect(res.lines.first.taxId, 101);
      expect(res.lines.first.taxPercent, 15.0);
      expect(res.lines.first.taxCode, '15');
    });

    test('discount becomes its own exempt Discount line', () {
      final res = buildFiscalLines(
        doc: _doc(
          discount: 10,
          lineItems: [
            LineItem(
              description: 'Consulting',
              quantity: 2,
              unitPrice: 50,
              taxTreatment: 'standard',
            ),
          ],
        ),
        config: _config,
        org: _org(),
      );
      expect(res.ok, isTrue);
      final discountLine = res.lines.last;
      expect(discountLine.lineType, 'Discount');
      expect(discountLine.price, -10);
      expect(discountLine.taxId, 103);
      expect(discountLine.taxPercent, isNull);

      // FDMS total equals the printed document total:
      // 100 subtotal + 15 tax − 10 discount = 105.
      expect(fiscalTotalCents(res.lines), 10500);
    });

    test('zero-rated documents map to the 0% FDMS tax entry', () {
      final res = buildFiscalLines(
        doc: _doc(
          taxRate: 0,
          discount: 0,
          lineItems: [
            LineItem(
              description: 'Consulting',
              quantity: 2,
              unitPrice: 50,
              taxTreatment: 'zero_rated',
            ),
          ],
        ),
        config: _config,
        org: _org(),
      );
      expect(res.ok, isTrue);
      expect(res.lines.first.taxId, 102);
      expect(res.lines.first.taxPercent, 0.0);
      expect(fiscalTotalCents(res.lines), 10000);
    });

    test('unmatched tax treatment is refused instead of guessing', () {
      // Org configured at 12.5% while FDMS carries 15/0/exempt only.
      final org = Organization(id: 'o1', name: 'Test Co')
        ..taxDefinitions = [
          const TaxDefinition(
            id: 'std',
            name: 'VAT',
            rate: 12.5,
            type: TaxTreatment.standard,
            isDefault: true,
          ),
        ];
      org.taxEnabled = true;
      final res = buildFiscalLines(
        doc: _doc(taxRate: 12.5, lineItems: [
          LineItem(
            description: 'Consulting',
            quantity: 2,
            unitPrice: 50,
            taxTreatment: 'standard',
          ),
        ]),
        config: _config,
        org: org,
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('12.5%'));
    });

    test('empty documents are refused', () {
      final res = buildFiscalLines(
        doc: _doc(lineItems: const []),
        config: _config,
      );
      expect(res.ok, isFalse);
      expect(res.problem, contains('no line items'));
    });

    test('config problems are caught before anything is sent', () {
      expect(fiscalConfigProblem(null), isNotNull);
      expect(
        fiscalConfigProblem(const ZimraConfig(applicableTaxes: [], qrUrl: '')),
        isNotNull,
      );
      expect(
        fiscalConfigProblem(
          const ZimraConfig(applicableTaxes: [], qrUrl: 'https://x/'),
        ),
        isNotNull,
      );
      expect(fiscalConfigProblem(_config), isNull);
    });
  });

  group('receipt types and original-document reference', () {
    test('document types map onto the FDMS ReceiptTypeEnum', () {
      expect(
        fiscalReceiptType(DocumentType.invoice).apiValue,
        'FiscalInvoice',
      );
      expect(
        fiscalReceiptType(DocumentType.receipt).apiValue,
        'FiscalInvoice',
      );
      expect(fiscalReceiptType(DocumentType.creditNote).apiValue, 'CreditNote');
      expect(fiscalReceiptType(DocumentType.debitNote).apiValue, 'DebitNote');
    });

    test('only credit/debit notes reference the original document', () {
      final invoice = _doc();
      expect(
        fiscalOriginalReference(doc: invoice, deviceId: 38513),
        isNull,
      );

      final original = _doc()
        ..fiscalStatus = 'fiscalised'
        ..fiscalDeviceId = 38513
        ..fiscalDayNo = 4
        ..fiscalReceiptGlobalNo = 42
        ..fiscalReceiptId = 900;
      final creditNote = _doc(docType: 'credit_note', convertedFrom: 'doc-1');

      final ref = fiscalOriginalReference(
        doc: creditNote,
        deviceId: 38513,
        original: original,
      );
      expect(ref, isNotNull);
      expect(
        ref!.toJson(),
        {
          'receiptID': 900,
          'deviceID': 38513,
          'receiptGlobalNo': 42,
          'fiscalDayNo': 4,
        },
      );

      // An unfiscalised original yields no reference.
      expect(
        fiscalOriginalReference(
          doc: creditNote,
          deviceId: 38513,
          original: _doc(),
        ),
        isNull,
      );
    });
  });

  group('fiscal state transitions', () {
    Map<String, dynamic> payload() => {
      'receipt': {
        'receiptCounter': 3,
        'receiptGlobalNo': 42,
        'receiptDate': '2026-09-25T10:00:00',
        'receiptDeviceSignature': {
          'hash': 'aGFzaA==',
          'signature': base64Encode(utf8.encode('sig-bytes')),
        },
      },
    };

    test('successful fiscalisation persists every contract field', () {
      final doc = _doc()
        ..fiscalStatus = 'pending'
        ..fiscalPendingPayload = '{}'
        ..fiscalQrPayload = 'stale-payload';

      applyFiscalisation(
        doc,
        deviceId: 38513,
        fiscalDayNo: 1,
        result: _result(payload()),
        qrPayload: 'QRPAYLOAD',
      );

      expect(doc.isFiscalised, isTrue);
      expect(doc.isFiscalPending, isFalse);
      expect(doc.fiscalDeviceId, 38513);
      expect(doc.fiscalDayNo, 1);
      expect(doc.fiscalReceiptNo, 3);
      expect(doc.fiscalReceiptGlobalNo, 42);
      expect(doc.fiscalReceiptId, 501);
      expect(doc.fiscalOperationId, '0HMQCKLK5B38G:00000006');
      expect(doc.fiscalQrPayload, 'QRPAYLOAD');
      expect(doc.fiscalVerificationCode, 'QRPAYLOAD');
      expect(doc.fiscalSignature, base64Encode(utf8.encode('sig-bytes')));
      expect(doc.fiscalisedAt, isNotNull);
      expect(doc.fiscalPendingPayload, isNull);
      expect(doc.fiscalError, isNull);
    });

    test('pending documents never claim fiscal status', () {
      final doc = _doc();
      final record = PendingFiscalRecord.fromPayload(
        deviceId: 38513,
        fiscalDayNo: 1,
        receiptPayload: payload(),
      );
      markFiscalPending(doc, record: record);

      expect(doc.isFiscalPending, isTrue);
      expect(doc.isFiscalised, isFalse);
      expect(doc.fiscalVerificationCode, isNull);
      expect(doc.fiscalQrPayload, isNull);
      expect(doc.fiscalPendingPayload, isNotNull);
      expect(PendingFiscalRecord.decode(doc.fiscalPendingPayload)!.receiptGlobalNo, 42);
    });

    test('rejected documents never claim fiscal status', () {
      final doc = _doc()..fiscalQrPayload = 'stale';
      markFiscalRejected(doc, 'ZIMRA RCP020: Receipt rejected (400)');

      expect(doc.isFiscalRejected, isTrue);
      expect(doc.isFiscalised, isFalse);
      expect(doc.fiscalVerificationCode, isNull);
      expect(doc.fiscalQrPayload, isNull);
      expect(doc.fiscalError, contains('Receipt rejected'));
      expect(doc.fiscalPendingPayload, isNull);
    });

    test('pending record round-trips and rebuilds the exact QR payload', () {
      final record = PendingFiscalRecord.fromPayload(
        deviceId: 38513,
        fiscalDayNo: 1,
        receiptPayload: payload(),
      );
      final decoded = PendingFiscalRecord.decode(record.encode());
      expect(decoded, isNotNull);
      expect(decoded!.receiptCounter, 3);
      expect(decoded.receiptGlobalNo, 42);
      expect(decoded.deviceId, 38513);
      expect(decoded.payload, record.payload);

      expect(
        record.qrPayload('https://verify.zimra.example/'),
        ZimraFiscalDevice.buildVerificationQrData(
          deviceId: 38513,
          receiptDate: DateTime(2026, 9, 25, 10, 0),
          receiptGlobalNo: 42,
          deviceSignatureBase64: base64Encode(utf8.encode('sig-bytes')),
          qrBaseUrl: 'https://verify.zimra.example/',
        ),
      );
      expect(PendingFiscalRecord.decode('not json'), isNull);
      expect(PendingFiscalRecord.decode(null), isNull);
    });

    test('a credit note keeps its OWN verification data (case H)', () {
      final invoice = _doc()
        ..fiscalStatus = 'fiscalised'
        ..fiscalQrPayload = 'INVOICE-QR'
        ..fiscalReceiptGlobalNo = 42;
      final creditNote = _doc(docType: 'credit_note', convertedFrom: 'doc-1');

      final cnPayload = {
        'receipt': {
          'receiptCounter': 1,
          'receiptGlobalNo': 43,
          'receiptDate': '2026-09-26T09:00:00',
          'receiptDeviceSignature': {
            'hash': 'aGFzaA==',
            'signature': base64Encode(utf8.encode('cn-sig')),
          },
        },
      };
      applyFiscalisation(
        creditNote,
        deviceId: 38513,
        fiscalDayNo: 1,
        result: _result(cnPayload, receiptId: 502),
        qrPayload: 'CN-OWN-PAYLOAD',
      );

      expect(creditNote.isFiscalised, isTrue);
      expect(creditNote.fiscalQrPayload, 'CN-OWN-PAYLOAD');
      expect(creditNote.fiscalReceiptGlobalNo, 43);
      expect(creditNote.fiscalReceiptId, 502);
      expect(creditNote.fiscalQrPayload, isNot(invoice.fiscalQrPayload));
    });
  });
}
