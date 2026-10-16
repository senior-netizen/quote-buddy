// PDF fiscal verification tests (cases C, D, E, F, G, J).
//
// Verifies that fiscalised documents render the ZIMRA fiscal section with
// the verification payload and QR code, that reprints reproduce the stored
// payload, and that non-fiscalised documents never claim fiscal status.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/client.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/pdf_service.dart';

const _payload =
    'https://verify.zimra.example/0000038513250920260000000042a1b2c3d4e5f60718';

QuoteflowDocument _doc({String? status = 'fiscalised'}) => QuoteflowDocument(
  id: 'd1',
  docType: 'invoice',
  docNumber: 'INV-001',
  issueDate: '2026-09-25',
  lineItems: [LineItem(description: 'Consulting', quantity: 2, unitPrice: 50)],
  taxRate: 15,
  discount: 0,
  subtotal: 100,
  taxAmount: 15,
  total: 115,
  clientId: 'c1',
  createdAt: '2026-09-25T10:00:00',
  fiscalStatus: status,
  fiscalDeviceId: 38513,
  fiscalDayNo: 1,
  fiscalReceiptNo: 3,
  fiscalReceiptGlobalNo: 42,
  fiscalQrPayload: status == 'fiscalised' ? _payload : null,
  fiscalSignature: 'c2lnbmF0dXJl',
  fiscalReceiptId: status == 'fiscalised' ? 501 : null,
  fiscalOperationId: status == 'fiscalised' ? '0HMQCKLK5B38G:00000006' : null,
  fiscalisedAt: status == 'fiscalised' ? '2026-09-25T14:30:05' : null,
);

Organization _org({String theme = 'classic'}) => Organization(
  id: 'o1',
  name: 'Acme Traders',
  currency: 'USD',
  pdfTheme: theme,
);

/// Inflate every FlateDecode stream in the PDF and return the PDF string
/// literals drawn with Tj operators, joined in document order. Falls back
/// to the raw inflated content when no literal matched.
String _pdfText(Uint8List bytes) {
  final latin = latin1.decode(bytes);
  final streamRe = RegExp(r'stream\r?\n([\s\S]*?)endstream');
  final buffer = StringBuffer();
  var matchedLiteral = false;

  for (final m in streamRe.allMatches(latin)) {
    final raw = latin1.encode(m.group(1)!);
    List<int>? decoded;
    for (var trim = 0; trim <= 4 && decoded == null; trim++) {
      try {
        decoded = ZLibDecoder().convert(raw.sublist(0, raw.length - trim));
      } catch (_) {
        // try a shorter stream (trailing EOL bytes)
      }
    }
    if (decoded == null) continue;
    final content = latin1.decode(decoded);
    // Base-14 text is emitted as strings inside TJ arrays as well as Tj.
    final litRe = RegExp(r'\(((?:\\[\(\)\\]|[^()\\])*)\)');
    for (final lit in litRe.allMatches(content)) {
      matchedLiteral = true;
      buffer.writeln(
        lit
            .group(1)!
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\\', r'\'),
      );
    }
    if (!matchedLiteral) buffer.writeln(content);
  }
  return buffer.toString();
}

bool _containsFlat(String text, String needle) => text
    .replaceAll(RegExp(r'\s+'), '')
    .contains(needle.replaceAll(RegExp(r'\s+'), ''));

/// Breadth-first walk over the few container widgets used here.
Iterable<pw.Widget> _childrenOf(pw.Widget w) sync* {
  final d = w as dynamic;
  try {
    final c = d.child;
    if (c is pw.Widget) yield c;
  } catch (_) {}
  try {
    final cs = d.children;
    if (cs is Iterable) yield* cs.whereType<pw.Widget>();
  } catch (_) {}
}

pw.Widget? _findFirst(pw.Widget root, bool Function(pw.Widget) test) {
  if (test(root)) return root;
  for (final c in _childrenOf(root)) {
    final hit = _findFirst(c, test);
    if (hit != null) return hit;
  }
  return null;
}

void main() {
  setUpAll(() => PdfService.useBuiltInFonts = true);
  tearDownAll(() => PdfService.useBuiltInFonts = false);
  test(
    'fiscal reprint preserves transmitted currency and buyer after business/customer edits',
    () async {
      final doc = _doc();
      doc.fiscalRecord = {
        'request': {
          'receipt': {
            'receiptCurrency': 'USD',
            'buyerData': {
              'buyerRegisterName': 'Original Buyer Ltd',
              'buyerTIN': '2000000002',
              'buyerAddress': {'street': 'Original Road', 'city': 'Harare'},
            },
          },
        },
      };
      final bytes = await PdfService.generatePdf(
        doc: doc,
        client: Client(
          id: 'c1',
          companyName: 'Changed Customer',
          registeredName: 'Changed Customer',
          tin: '2000000003',
        ),
        org: _org().copyWith(currency: 'ZWG'),
      );
      final text = _pdfText(bytes);
      expect(_containsFlat(text, 'Original Buyer Ltd'), isTrue);
      expect(_containsFlat(text, 'Original Road'), isTrue);
      expect(_containsFlat(text, 'Changed Customer'), isFalse);
      expect(_containsFlat(text, 'ZiG'), isFalse);
    },
  );
  group('case C — generated PDF carries the verification code', () {
    for (final theme in [
      'classic',
      'modern',
      'minimal',
      'bold',
      'elegant',
      'fresh',
    ]) {
      test('$theme theme renders FISCAL DETAILS with the payload', () async {
        final bytes = await PdfService.generatePdf(
          doc: _doc(),
          client: null,
          org: _org(theme: theme),
        );
        final text = _pdfText(bytes);
        if (const bool.fromEnvironment('WRITE_PDF_PREVIEWS')) {
          final file = File('tmp/pdfs/fiscal-$theme.pdf');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        }
        expect(latin1.decode(bytes), contains('/URI'));

        expect(
          _containsFlat(text, 'FISCAL DETAILS'),
          isTrue,
          reason: 'the fiscal section must be present in the $theme PDF',
        );
        expect(_containsFlat(text, 'Fiscal Device ID'), isTrue);
        expect(_containsFlat(text, 'Fiscal Day'), isTrue);
        expect(_containsFlat(text, 'Receipt Number'), isTrue);
        expect(
          _containsFlat(text, _payload),
          isTrue,
          reason: 'the ZIMRA verification payload must be printed verbatim',
        );
      });
    }
  });

  group('cases D + E — QR code', () {
    test('fiscal block embeds a square QR of exactly the stored payload', () {
      final block = PdfService.fiscalBlock(
        _doc(),
        PdfColors.black,
        PdfColors.grey,
        PdfColors.grey300,
      );
      final qr = _findFirst(block, (w) => w is pw.BarcodeWidget);

      expect(qr, isNotNull, reason: 'the QR widget must be part of the block');
      final bw = qr! as pw.BarcodeWidget;
      expect(bw.dataString, _payload, reason: 'QR encodes the ZIMRA payload');
      expect(bw.barcode.runtimeType, pw.Barcode.qrCode().runtimeType);
      expect(bw.width, bw.height, reason: 'QR must stay square');
      expect(bw.drawText, isFalse, reason: 'no human-readable text under QR');
      expect(bw.color, PdfColors.black, reason: 'high contrast');
    });

    test('QR white container provides the quiet zone', () {
      final block = PdfService.fiscalBlock(
        _doc(),
        PdfColors.black,
        PdfColors.grey,
        PdfColors.grey300,
      );
      // Walk: Container > Column > Row > (Expanded, SizedBox, Container)
      final qrHost = _findFirst(
        block,
        (w) =>
            w is pw.Container &&
            w.decoration?.color == PdfColors.white &&
            w.padding != null,
      );
      expect(qrHost, isNotNull, reason: 'white quiet-zone wrapper expected');
    });
  });

  group('case F — reprint reproduces the original fiscal data', () {
    test('two PDF generations yield the identical stored payload', () async {
      final doc = _doc();
      final before = (
        doc.fiscalQrPayload,
        doc.fiscalReceiptNo,
        doc.fiscalReceiptGlobalNo,
        doc.fiscalSignature,
      );

      final first = await PdfService.generatePdf(
        doc: doc,
        client: null,
        org: _org(),
      );
      final second = await PdfService.generatePdf(
        doc: doc,
        client: null,
        org: _org(),
      );

      final textA = _pdfText(first);
      final textB = _pdfText(second);
      expect(_containsFlat(textA, _payload), isTrue);
      expect(_containsFlat(textB, _payload), isTrue);

      // Generating never mutates fiscal state — no re-fiscalisation.
      expect((
        doc.fiscalQrPayload,
        doc.fiscalReceiptNo,
        doc.fiscalReceiptGlobalNo,
        doc.fiscalSignature,
      ), before);
    });

    test('the printed payload parses back to the stored fiscal fields', () {
      final match = RegExp(
        r'^(https://.+)/(\d{10})(\d{2})(\d{2})(\d{4})(\d{10})([0-9a-f]{16})$',
      ).firstMatch(_payload);
      expect(match, isNotNull);
      expect(int.parse(match!.group(2)!), 38513);
      expect('${match.group(3)}${match.group(4)}', '2509');
      expect(match.group(5), '2026');
      expect(int.parse(match.group(6)!), 42);
      expect(match.group(7), 'a1b2c3d4e5f60718');
    });
  });

  group('case G — never fiscal before FDMS success', () {
    for (final status in ['pending', 'rejected', null]) {
      test('status "$status" prints no fiscal section', () async {
        final bytes = await PdfService.generatePdf(
          doc: _doc(status: status),
          client: null,
          org: _org(),
        );
        expect(_containsFlat(_pdfText(bytes), 'FISCAL DETAILS'), isFalse);
        expect(PdfService.fiscalVisible(_doc(status: status)), isFalse);
      });
    }

    test('quotes are never treated as fiscal documents', () {
      final quote = _doc()..docType = 'quote';
      expect(PdfService.fiscalVisible(quote), isFalse);
      expect(quote.isFiscalType, isFalse);
    });
  });
}
