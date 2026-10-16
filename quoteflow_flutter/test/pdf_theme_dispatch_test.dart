// Theme dispatch regression tests.
//
// The user reported that choosing a document theme in Settings did not
// change the rendered PDF. These tests pin the dispatch end to end:
//  * every theme id must reach the generator (no silent fallthrough to
//    classic — PDFs carry real color/typography operators, so each theme
//    inflates to distinct drawing instructions),
//  * per-document overrides must beat the organization default,
//  * an unknown persisted theme id must degrade safely instead of crashing.
//
// Comparison runs over the INFLATED content streams, not raw bytes: PDF
// trailers embed a random /ID and creation timestamps, so byte equality is
// meaningless even for identical generations.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/services/pdf_service.dart';

QuoteflowDocument _doc() => QuoteflowDocument(
  id: 'd1',
  docType: 'invoice',
  docNumber: 'INV-001',
  issueDate: '2026-09-25',
  lineItems: [LineItem(description: 'Consulting', quantity: 2, unitPrice: 50)],
  taxRate: 0,
  discount: 0,
  subtotal: 100,
  taxAmount: 0,
  total: 100,
  clientId: 'c1',
  createdAt: '2026-09-25T10:00:00',
);

Organization _org({String theme = 'classic', String? tableStyle}) =>
    Organization(
      id: 'o1',
      name: 'Acme Traders',
      currency: 'USD',
      pdfTheme: theme,
      tableStyle: tableStyle,
    );

/// Inflate every FlateDecode stream and return the drawing operators of the
/// page content (skipping fonts, images and metadata), normalised.
String _content(Uint8List bytes) {
  final latin = latin1.decode(bytes);
  final streamRe = RegExp(r'stream\r?\n([\s\S]*?)endstream');
  final buffer = StringBuffer();
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
    // Keep only page drawing operators: font/TT/Widths objects and binary
    // blobs are excluded by requiring operator-ish lines.
    if (content.contains(' re ') || content.contains(' Tj') || content.contains(' Tf') || content.contains(' rg') || content.contains('Do')) {
      buffer.writeln(content);
    }
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// True when two PDFs drawn differently in a way that survives the random
/// trailer id: content streams differ.
bool _rendersDifferently(Uint8List a, Uint8List b) => _content(a) != _content(b);

void main() {
  setUpAll(() => PdfService.useBuiltInFonts = true);
  tearDownAll(() => PdfService.useBuiltInFonts = false);

  group('organization theme selection reaches the rendered PDF', () {
    const themes = [
      'classic',
      'modern',
      'minimal',
      'bold',
      'elegant',
      'fresh',
      'boutique',
      'editorial',
      'ledger',
      'contractor',
      'studio',
    ];

    test('every theme id renders and differs from classic', () async {
      final classic = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'classic'),
      );
      expect(classic, isNotEmpty);

      for (final theme in themes.skip(1)) {
        final bytes = await PdfService.generatePdf(
          doc: _doc(),
          client: null,
          org: _org(theme: theme),
        );
        expect(bytes, isNotEmpty, reason: '$theme produced an empty PDF');
        expect(
          _rendersDifferently(classic, bytes),
          isTrue,
          reason: '$theme rendered identically to classic — the theme '
              'choice is not reaching the generator',
        );
      }
    });

    test('every theme pair renders differently', () async {
      final rendered = <String, String>{
        for (final t in themes)
          t: _content(
            await PdfService.generatePdf(
              doc: _doc(),
              client: null,
              org: _org(theme: t),
            ),
          ),
      };
      for (var i = 0; i < themes.length; i++) {
        for (var j = i + 1; j < themes.length; j++) {
          expect(
            rendered[themes[i]] != rendered[themes[j]],
            isTrue,
            reason: '${themes[i]} and ${themes[j]} rendered identically — '
                'one theme falls through to the other',
          );
        }
      }
    });

    test('identical generations have identical content (comparator sanity)',
        () async {
      final a = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(),
      );
      final b = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(),
      );
      // Raw bytes may differ (random /ID); the drawn content must not.
      expect(_content(a), _content(b));
    });

    test('table style changes the rendered table', () async {
      final striped = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'classic', tableStyle: 'striped'),
      );
      final bordered = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'classic', tableStyle: 'bordered'),
      );
      expect(_rendersDifferently(striped, bordered), isTrue);
    });
  });

  group('per-document overrides', () {
    test('doc.pdfTheme wins over the org default', () async {
      final boldRef = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'bold'),
      );
      final overridden = await PdfService.generatePdf(
        doc: _doc()..pdfTheme = 'bold',
        client: null,
        org: _org(theme: 'classic'),
      );
      expect(
        _rendersDifferently(boldRef, overridden),
        isFalse,
        reason: 'doc.pdfTheme=bold must render like a bold organisation, '
            'not like the org default',
      );
    });

    test('doc.tableStyle wins over the org default', () async {
      final stripedRef = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'classic', tableStyle: 'striped'),
      );
      final overridden = await PdfService.generatePdf(
        doc: _doc()..tableStyle = 'striped',
        client: null,
        org: _org(theme: 'classic'),
      );
      expect(_rendersDifferently(stripedRef, overridden), isFalse);
    });
  });

  group('unknown theme ids', () {
    test('an unknown org theme falls back to the classic look, not a crash',
        () async {
      final legacy = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'not-a-theme'),
      );
      final classic = await PdfService.generatePdf(
        doc: _doc(),
        client: null,
        org: _org(theme: 'classic'),
      );
      expect(legacy, isNotEmpty);
      expect(_content(legacy), _content(classic));
    });

    test('normalizedPdfTheme maps every id and degrades unknowns', () {
      expect(normalizedPdfTheme('modern'), 'modern');
      expect(normalizedPdfTheme(' BOLD '), 'bold');
      expect(normalizedPdfTheme(null), 'classic');
      expect(normalizedPdfTheme(''), 'classic');
      expect(normalizedPdfTheme('vaporwave'), 'classic');
      for (final id in pdfThemeIds) {
        expect(normalizedPdfTheme(id), id);
      }
    });
  });
}
