import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/pdf_service.dart';

const referenceThemes = [
  'boutique',
  'editorial',
  'ledger',
  'contractor',
  'studio',
];
void main() {
  setUpAll(() => PdfService.useBuiltInFonts = true);
  tearDownAll(() => PdfService.useBuiltInFonts = false);
  final org = Organization(
    id: 'demo',
    name: 'Mavambo Studio',
    shortName: 'Mavambo Studio',
    currency: 'USD',
    address: '14 Samora Machel Avenue',
    city: 'Harare',
    country: 'Zimbabwe',
    phone: '+263 77 123 4567',
    emails: ['accounts@example.test'],
    bankName: 'Example Bank',
    bankAccountName: 'Mavambo Studio',
    bankAccountNumber: '123456789',
    paymentInstructions:
        'Please use the document number as your payment reference.',
  );
  final client = Client(
    id: 'client',
    companyName: 'Acacia Trading',
    street: 'Park Road',
    houseNo: '10',
    city: 'Harare',
    country: 'Zimbabwe',
    email: 'accounts@acacia.example',
  );
  QuoteflowDocument document(
    String theme, {
    bool many = false,
    bool receipt = false,
  }) => QuoteflowDocument(
    id: 'sample',
    docType: receipt ? 'receipt' : 'invoice',
    docNumber: receipt ? 'RC-2026-0042' : 'INV-2026-0042',
    issueDate: '2026-09-30',
    dueDate: receipt ? null : '2026-10-14',
    lineItems: many
        ? List.generate(
            70,
            (i) => LineItem(
              description:
                  'Item ${i + 1}: detailed consulting service and project delivery',
              quantity: 2,
              unitPrice: 50,
            ),
          )
        : [
            LineItem(
              description: 'Brand identity design',
              quantity: 1,
              unitPrice: 500,
            ),
            LineItem(
              description: 'Business stationery',
              quantity: 2,
              unitPrice: 150,
            ),
            LineItem(
              description: 'Website design',
              quantity: 1,
              unitPrice: 800,
            ),
            LineItem(
              description: 'Social media graphics',
              quantity: 5,
              unitPrice: 50,
            ),
          ],
    taxRate: 0,
    discount: 0,
    subtotal: many ? 7000 : 1850,
    taxAmount: 0,
    total: many ? 7000 : 1850,
    clientId: 'client',
    createdAt: '2026-09-30',
    pdfTheme: theme,
    notes: 'Thank you for choosing Mavambo Studio.',
  );
  for (final theme in referenceThemes) {
    test(
      '$theme renders invoices, receipts, long tables and fiscal records',
      () async {
        for (final receipt in [false, true]) {
          final bytes = await PdfService.generatePdf(
            doc: document(theme, receipt: receipt),
            client: client,
            org: org,
          );
          expect(bytes.length, greaterThan(1000));
          if (const bool.fromEnvironment('WRITE_THEME_SAMPLES')) {
            final dir = Directory('output/pdf');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/$theme-${receipt ? 'receipt' : 'invoice'}.pdf',
            ).writeAsBytes(bytes);
          }
        }
        final doc = document(theme, many: true)
          ..fiscalStatus = 'fiscalised'
          ..fiscalDeviceId = 123
          ..fiscalDayNo = 1
          ..fiscalReceiptNo = 42
          ..fiscalReceiptGlobalNo = 42
          ..fiscalReceiptId = 700
          ..fiscalQrPayload = 'https://example.test/verify/12342'
          ..fiscalRecord = {
            'request': {
              'receipt': {
                'buyerData': {
                  'buyerRegisterName': 'Acacia Trading Ltd',
                  'buyerTIN': '1234567890',
                },
              },
            },
            'response': {
              'validationErrors': [
                {
                  'code': 'RCPT043',
                  'color': 'Red',
                  'description': 'Missing buyer',
                },
              ],
            },
          };
        final bytes = await PdfService.generatePdf(
          doc: doc,
          client: client,
          org: org,
        );
        expect(bytes.length, greaterThan(1000));
        if (const bool.fromEnvironment('WRITE_THEME_SAMPLES'))
          await File('output/pdf/$theme-multipage.pdf').writeAsBytes(bytes);
      },
    );
  }
}
