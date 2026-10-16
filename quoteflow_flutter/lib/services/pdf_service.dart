import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/document.dart';
import '../models/client.dart';
import '../models/organization.dart';
import 'calculations.dart';

part 'pdf_reference_themes.dart';

/// Normalises a persisted theme id so unknown/legacy values can never
/// silently fall through to classic: every generator is reachable and an
/// unknown id degrades to the plain 'classic' look only here.
String normalizedPdfTheme(String? theme) {
  final t = (theme ?? '').trim().toLowerCase();
  return pdfThemeIds.contains(t) ? t : 'classic';
}

/// Available PDF theme identifiers.
const List<String> pdfThemeIds = [
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

/// Human-readable labels for the theme picker.
String pdfThemeLabel(String id) {
  switch (id) {
    case 'classic':
      return 'Classic';
    case 'modern':
      return 'Modern';
    case 'minimal':
      return 'Minimal';
    case 'bold':
      return 'Bold';
    case 'elegant':
      return 'Elegant';
    case 'fresh':
      return 'Fresh';
    default:
      return id;
  }
}

/// Short description shown under each theme card.
String pdfThemeDescription(String id) {
  switch (id) {
    case 'classic':
      return 'Clean & professional with subtle orange accents';
    case 'modern':
      return 'Dark header bar with crisp typography';
    case 'minimal':
      return 'Light and airy with thin rules';
    case 'bold':
      return 'Strong colors and heavy type for impact';
    case 'elegant':
      return 'Formal serif letterhead in navy and gold';
    case 'fresh':
      return 'Bright teal with soft cards and rounded corners';
    default:
      return '';
  }
}

/// Available line-items table styles. 'auto' resolves to each theme's own
/// default (see [effectiveTableStyle]).
const List<String> tableStyleIds = [
  'auto',
  'striped',
  'bordered',
  'outlined',
  'minimal',
];

/// Human-readable labels for the table style picker.
String tableStyleLabel(String id) {
  switch (id) {
    case 'auto':
      return 'Theme default';
    case 'striped':
      return 'Striped';
    case 'bordered':
      return 'Bordered';
    case 'outlined':
      return 'Outlined';
    case 'minimal':
      return 'Minimal';
    default:
      return id;
  }
}

/// Short description shown under each table style option.
String tableStyleDescription(String id) {
  switch (id) {
    case 'auto':
      return 'Each PDF theme keeps its own signature table look';
    case 'striped':
      return 'Colored header band with alternating row shading';
    case 'bordered':
      return 'Full grid lines around every cell, colored header';
    case 'outlined':
      return 'Header underline with light row separators';
    case 'minimal':
      return 'No rules — open spacing with a light header line';
    default:
      return '';
  }
}

/// Resolve the effective table style for a given theme + stored preference.
/// A stored [tableStyle] other than 'auto' wins; otherwise each theme falls
/// back to its own default look.
String effectiveTableStyle(String pdfTheme, String? tableStyle) {
  if (tableStyle != null &&
      tableStyleIds.contains(tableStyle) &&
      tableStyle != 'auto') {
    return tableStyle;
  }
  switch (pdfTheme) {
    case 'contractor':
      return 'bordered';
    case 'editorial':
      return 'minimal';
    case 'ledger':
    case 'studio':
      return 'outlined';
    case 'modern':
    case 'bold':
    case 'fresh':
      return 'striped';
    case 'minimal':
      return 'minimal';
    default:
      return 'outlined';
  }
}

/// True when the org wants its logo on the right side of the PDF header.
bool _logoRight(Organization org) => org.logoPosition == 'right';

/// Header logo height in points, clamped to a sane range.
double _logoSize(Organization org) => (org.logoSize ?? 36).clamp(20.0, 80.0);

/// Accent colour used across the entire theme.
PdfColor _accent(String theme) {
  switch (theme) {
    case 'modern':
      return PdfColor.fromHex('#1e293b');
    case 'minimal':
      return PdfColor.fromHex('#64748b');
    case 'bold':
      return PdfColor.fromHex('#dc2626');
    default:
      return PdfColor.fromHex('#f97316');
  }
}

/// Bundle of fonts used by the PDF generator.
class _Fonts {
  final pw.ThemeData theme;
  final pw.Font bold;
  final pw.Font italic;

  _Fonts(this.theme, this.bold, this.italic);
}

class PdfService {
  /// Deterministic offline font path for PDF regression tests.
  @visibleForTesting
  static bool useBuiltInFonts = false;

  /// Generate PDF bytes for a document.
  ///
  /// Per-document overrides (doc.pdfTheme / logoPosition / tableStyle) win
  /// over the organization's global PDF settings when present.
  static Future<Uint8List> generatePdf({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final receipt = doc.isFiscalised
        ? ((doc.fiscalRecord?['request'] as Map?)?['receipt'] as Map?)
        : null;
    final currency = receipt?['receiptCurrency'];
    final resolved = _resolvePdfOrg(org, doc).copyWith(
      currency: currency is String && RegExp(r'^[A-Z]{3}$').hasMatch(currency)
          ? currency
          : org.currency,
    );
    // Reprints must preserve the buyer transmitted to FDMS, even after customer edits.
    final buyer = receipt?['buyerData'] as Map?;
    if (buyer != null) {
      final address = buyer['buyerAddress'] as Map? ?? {};
      final contacts = buyer['buyerContacts'] as Map? ?? {};
      client = Client(
        id: client?.id ?? doc.clientId,
        companyName:
            buyer['buyerRegisterName'] as String? ?? client?.companyName ?? '',
        registeredName: buyer['buyerRegisterName'] as String?,
        tradeName: buyer['buyerTradeName'] as String?,
        tin: buyer['buyerTIN'] as String?,
        vatRegistered: buyer['vatNumber'] != null,
        vatNumber: buyer['vatNumber'] as String?,
        houseNo: address['houseNo'] as String?,
        street: address['street'] as String?,
        city: address['city'] as String?,
        province: address['province'] as String?,
        email: contacts['email'] as String?,
        phone: contacts['phoneNo'] as String?,
        orgId: doc.orgId,
      );
    }
    final theme = normalizedPdfTheme(resolved.pdfTheme);
    switch (theme) {
      case 'boutique':
      case 'editorial':
      case 'ledger':
      case 'contractor':
      case 'studio':
        return _ReferenceThemes.generate(
          doc: doc,
          client: client,
          org: resolved,
        );
      case 'modern':
        return _generateModern(doc: doc, client: client, org: resolved);
      case 'minimal':
        return _generateMinimal(doc: doc, client: client, org: resolved);
      case 'bold':
        return _generateBold(doc: doc, client: client, org: resolved);
      case 'elegant':
        return _generateElegant(doc: doc, client: client, org: resolved);
      case 'fresh':
        return _generateFresh(doc: doc, client: client, org: resolved);
      default:
        return _generateClassic(doc: doc, client: client, org: resolved);
    }
  }

  /// An org view whose PDF style fields carry the document's overrides,
  /// so the theme generators (which read everything from [Organization org])
  /// pick them up without extra plumbing. Returns the original org when
  /// there is nothing to override.
  static Organization _resolvePdfOrg(Organization org, QuoteflowDocument doc) {
    if (doc.pdfTheme == null &&
        doc.logoPosition == null &&
        doc.tableStyle == null) {
      return org;
    }
    return org.copyWith(
      pdfTheme: doc.pdfTheme,
      logoPosition: doc.logoPosition,
      tableStyle: doc.tableStyle,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  CLASSIC
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateClassic({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final ink = PdfColor.fromHex('#0a0a0a');
    final muted = PdfColor.fromHex('#6b7280');
    final hair = PdfColor.fromHex('#e5e7eb');
    final currency = org.currency;
    final f = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, ink, muted, hair),
        build: (ctx) => [
          _buildHeader(doc, org, f, ink, muted),
          pw.SizedBox(height: 20),
          pw.Container(height: 0.5, color: hair),
          pw.SizedBox(height: 20),
          _buildFromToDates(doc, org, client, ink, muted),
          pw.SizedBox(height: 24),
          _buildTable(
            doc.lineItems,
            currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 240,
                child: _buildTotals(doc, currency, ink, muted, hair),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _label('NOTES', muted),
            pw.SizedBox(height: 4),
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: ink)),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, ink, muted),
          ],
          ..._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════
  //  MODERN — dark header band
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateModern({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final accent = _accent('modern');
    final ink = PdfColor.fromHex('#0f172a');
    final muted = PdfColor.fromHex('#64748b');
    final hair = PdfColor.fromHex('#e2e8f0');
    final currency = org.currency;
    final f = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 0, 48, 48),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, ink, muted, hair),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(0, 40, 0, 24),
            color: accent,
            child: pw.Column(
              crossAxisAlignment: _logoRight(org)
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                _headerLogo(
                  org,
                  PdfColor.fromHex('#ffffff'),
                  f,
                  height: _logoSize(org),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  doc.type.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#94a3b8'),
                    letterSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  doc.docNumber,
                  style: pw.TextStyle(
                    font: f.bold,
                    fontSize: 20,
                    color: PdfColor.fromHex('#ffffff'),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _buildFromToDates(doc, org, client, ink, muted),
          pw.SizedBox(height: 24),
          _buildTable(
            doc.lineItems,
            currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
            accent: _accent('modern'),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 240,
                child: _buildTotals(doc, currency, ink, muted, hair),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _label('NOTES', muted),
            pw.SizedBox(height: 4),
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: ink)),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, ink, muted),
          ],
          ..._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════
  //  MINIMAL — lots of whitespace, thin rules
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateMinimal({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final ink = PdfColor.fromHex('#1e293b');
    final muted = PdfColor.fromHex('#94a3b8');
    final hair = PdfColor.fromHex('#f1f5f9');
    final currency = org.currency;
    final f = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 52),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, ink, muted, hair),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_logoRight(org))
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        doc.type.label.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: muted,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        doc.docNumber,
                        style: pw.TextStyle(
                          font: f.bold,
                          fontSize: 14,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              _headerLogo(org, ink, f, height: _logoSize(org)),
              if (!_logoRight(org))
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        doc.type.label.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: muted,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        doc.docNumber,
                        style: pw.TextStyle(
                          font: f.bold,
                          fontSize: 14,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Container(height: 0.3, color: muted),
          pw.SizedBox(height: 24),
          _buildFromToDates(doc, org, client, ink, muted),
          pw.SizedBox(height: 28),
          _buildTable(
            doc.lineItems,
            currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 220,
                child: _buildTotals(doc, currency, ink, muted, hair),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 28),
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: muted)),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, ink, muted),
          ],
          ..._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════
  //  BOLD — heavy accent bar, thick type
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateBold({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final accent = _accent('bold');
    final accentLight = PdfColor.fromHex('#fef2f2');
    final ink = PdfColor.fromHex('#111827');
    final muted = PdfColor.fromHex('#6b7280');
    final hair = PdfColor.fromHex('#e5e7eb');
    final currency = org.currency;
    final f = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(44),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, ink, muted, hair),
        build: (ctx) => [
          pw.Container(width: double.infinity, height: 6, color: accent),
          pw.SizedBox(height: 28),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (_logoRight(org))
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: accentLight,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          doc.type.label.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: accent,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        doc.docNumber,
                        style: pw.TextStyle(
                          font: f.bold,
                          fontSize: 18,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              pw.Expanded(
                child: _headerLogo(org, ink, f, height: _logoSize(org)),
              ),
              if (!_logoRight(org))
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: accentLight,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        doc.type.label.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: accent,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      doc.docNumber,
                      style: pw.TextStyle(
                        font: f.bold,
                        fontSize: 18,
                        color: ink,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(height: 1, color: ink),
          pw.SizedBox(height: 20),
          _buildFromToDates(doc, org, client, ink, muted),
          pw.SizedBox(height: 24),
          _buildTable(
            doc.lineItems,
            currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
            accent: accent,
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 240,
                child: _buildTotalsBold(
                  doc,
                  currency,
                  ink,
                  muted,
                  hair,
                  accent,
                ),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _label('NOTES', muted),
            pw.SizedBox(height: 4),
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: ink)),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, ink, muted),
          ],
          ..._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════
  //  ELEGANT — formal serif letterhead in navy & gold
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateElegant({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final navy = PdfColor.fromHex('#1f3a57');
    final muted = PdfColor.fromHex('#7a8698');
    final gold = PdfColor.fromHex('#a07f2d');
    final hair = PdfColor.fromHex('#e9e3d3');
    final currency = org.currency;
    final f = await _loadSerifFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 46),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, navy, muted, hair),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: _logoRight(org)
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child:
                    _logoWidget(org, height: _logoSize(org)) ??
                    pw.Text(
                      org.shortName ?? org.name,
                      textAlign: _logoRight(org)
                          ? pw.TextAlign.right
                          : pw.TextAlign.left,
                      style: pw.TextStyle(
                        font: f.bold,
                        fontSize: 19,
                        color: navy,
                        letterSpacing: 2,
                      ),
                    ),
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: _logoRight(org)
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child: pw.Container(width: 120, height: 0.8, color: gold),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: _logoRight(org)
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child: pw.Text(
                  doc.type.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: muted,
                    letterSpacing: 3,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: _logoRight(org)
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child: pw.Text(
                  doc.docNumber,
                  style: pw.TextStyle(font: f.bold, fontSize: 14, color: navy),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          _buildFromToDates(doc, org, client, navy, muted),
          pw.SizedBox(height: 26),
          _buildTable(
            doc.lineItems,
            currency,
            navy,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
            accent: navy,
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 220,
                child: _buildTotals(doc, currency, navy, muted, hair),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            pw.Text(
              doc.notes!,
              style: pw.TextStyle(font: f.italic, fontSize: 9.5, color: muted),
            ),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, navy, muted),
          ],
          ..._withFiscalSection(doc, navy, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════
  //  FRESH — bright teal with a soft rounded header band
  // ════════════════════════════════════════════════════════════════════

  static Future<Uint8List> _generateFresh({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    final pdf = pw.Document();
    final accent = PdfColor.fromHex('#0d9488');
    final accentDark = PdfColor.fromHex('#115e59');
    final accentSoft = PdfColor.fromHex('#f0fdfa');
    final ink = PdfColor.fromHex('#1f2937');
    final muted = PdfColor.fromHex('#6b7280');
    final hair = PdfColor.fromHex('#e2f0ee');
    final currency = org.currency;
    final f = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 0, 44, 40),
        theme: f.theme,
        footer: (ctx) => _buildFooter(ctx, org, ink, muted, hair),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: pw.BoxDecoration(
              color: accentSoft,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(14),
                bottomRight: pw.Radius.circular(14),
              ),
            ),
            child: pw.Row(
              children: [
                if (!_logoRight(org))
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _logoWidget(org, height: _logoSize(org)) ??
                            pw.Text(
                              org.shortName ?? org.name,
                              style: pw.TextStyle(
                                font: f.bold,
                                fontSize: 17,
                                color: accentDark,
                              ),
                            ),
                        if (org.emails.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            org.emails.first,
                            style: pw.TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#ffffff'),
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    doc.type.label.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                if (_logoRight(org))
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _logoWidget(org, height: _logoSize(org)) ??
                            pw.Text(
                              org.shortName ?? org.name,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                font: f.bold,
                                fontSize: 17,
                                color: accentDark,
                              ),
                            ),
                        if (org.emails.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            org.emails.first,
                            style: pw.TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 26),
          pw.Text(
            doc.docNumber,
            style: pw.TextStyle(font: f.bold, fontSize: 16, color: ink),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 1, color: accent),
          pw.SizedBox(height: 22),
          _buildFromToDates(doc, org, client, ink, muted),
          pw.SizedBox(height: 24),
          _buildTable(
            doc.lineItems,
            currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
            accent: accent,
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(
                width: 240,
                child: _buildTotalsBold(
                  doc,
                  currency,
                  ink,
                  muted,
                  hair,
                  accent,
                ),
              ),
            ],
          ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _label('NOTES', muted),
            pw.SizedBox(height: 4),
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: ink)),
          ],
          if (_hasSignature(doc)) ...[
            pw.SizedBox(height: 36),
            _signatureBlock(doc, org, ink, muted),
          ],
          ..._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  // ── Shared helpers ──────────────────────────────────────────────────

  static Future<_Fonts> _loadFonts() async {
    if (useBuiltInFonts) return _builtInFonts();
    try {
      final fontData = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansMedium();
      final fontItalic = await PdfGoogleFonts.notoSansItalic();
      final theme = pw.ThemeData.withFont(
        base: fontData,
        bold: fontBold,
        italic: fontItalic,
      );
      return _Fonts(theme, fontBold, fontItalic);
    } catch (_) {
      // Offline (or a font fetch failure): fall back to the base-14
      // fonts built into the PDF library so generation never breaks.
      return _builtInFonts();
    }
  }

  /// Serif type family used by the Elegant theme.
  static Future<_Fonts> _loadSerifFonts() async {
    if (useBuiltInFonts) return _builtInFonts();
    try {
      final fontData = await PdfGoogleFonts.merriweatherRegular();
      final fontBold = await PdfGoogleFonts.merriweatherBold();
      final fontItalic = await PdfGoogleFonts.merriweatherItalic();
      final theme = pw.ThemeData.withFont(
        base: fontData,
        bold: fontBold,
        italic: fontItalic,
      );
      return _Fonts(theme, fontBold, fontItalic);
    } catch (_) {
      return _builtInFonts();
    }
  }

  /// Base-14 PDF fonts — always available, no network needed.
  static Future<_Fonts> _builtInFonts() async {
    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final italic = pw.Font.helveticaOblique();
    final theme = pw.ThemeData.withFont(base: base, bold: bold, italic: italic);
    return _Fonts(theme, bold, italic);
  }

  /// Decode a logo/signature stored as a `data:image/...;base64,` URL (the
  /// format the settings screen writes) or a local file path. Returns null
  /// when nothing usable is stored, so callers fall back to text.
  static Uint8List? _decodeDataUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('data:image')) {
        return base64Decode(url.split(',').last);
      }
      if (!kIsWeb && (url.startsWith('/') || url.contains(':'))) {
        final file = File(url);
        if (file.existsSync()) return file.readAsBytesSync();
      }
    } catch (_) {}
    return null;
  }

  /// The org logo as a PDF image widget, or null when none is available.
  static pw.Widget? _logoWidget(Organization org, {double height = 36}) {
    final bytes = _decodeDataUrl(org.logoUrl);
    if (bytes == null) return null;
    try {
      return pw.Image(pw.MemoryImage(bytes), height: height);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _headerLogo(
    Organization org,
    PdfColor color,
    _Fonts f, {
    double height = 36,
  }) {
    final logo = _logoWidget(org, height: height);
    if (logo != null) {
      // A white chip keeps a typically dark logo visible on dark header
      // bands such as the Modern theme's slate bar.
      if (color.red > 0.9 && color.green > 0.9 && color.blue > 0.9) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ffffff'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: logo,
        );
      }
      return logo;
    }
    return pw.Text(
      org.shortName ?? org.name,
      style: pw.TextStyle(font: f.bold, fontSize: 20, color: color),
    );
  }

  static pw.Widget _buildHeader(
    QuoteflowDocument doc,
    Organization org,
    _Fonts f,
    PdfColor ink,
    PdfColor muted,
  ) {
    final right = _logoRight(org);
    final title = pw.Column(
      crossAxisAlignment: right
          ? pw.CrossAxisAlignment.start
          : pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          doc.type.label.toUpperCase(),
          style: pw.TextStyle(fontSize: 9, color: muted, letterSpacing: 3),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          doc.docNumber,
          style: pw.TextStyle(font: f.bold, fontSize: 16, color: ink),
        ),
      ],
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (right) pw.Expanded(child: title),
        _headerLogo(org, ink, f, height: _logoSize(org)),
        pw.SizedBox(width: 16),
        if (!right) pw.Expanded(child: title),
      ],
    );
  }

  static pw.Widget _buildFromToDates(
    QuoteflowDocument doc,
    Organization org,
    Client? client,
    PdfColor ink,
    PdfColor muted,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label('FROM', muted),
              pw.SizedBox(height: 6),
              _boldText(org.name, ink),
              ..._orgDetailLines(org).map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    line,
                    style: pw.TextStyle(fontSize: 9, color: muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label('BILLED TO', muted),
              pw.SizedBox(height: 6),
              _boldText(client?.companyName ?? '—', ink),
              if (client?.formattedAddress.isNotEmpty == true)
                _mutedText(client!.formattedAddress, muted),
              if (client?.email != null) _mutedText(client!.email!, muted),
              if (client?.phone != null) _mutedText(client!.phone!, muted),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.SizedBox(
          width: 140,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label('ISSUE DATE', muted),
              pw.SizedBox(height: 2),
              pw.Text(
                formatDate(doc.issueDate),
                style: pw.TextStyle(fontSize: 10, color: ink),
              ),
              if (doc.dueDate != null) ...[
                pw.SizedBox(height: 10),
                _label(
                  doc.type == DocumentType.invoice ||
                          doc.type == DocumentType.creditNote
                      ? 'DUE DATE'
                      : 'VALID UNTIL',
                  muted,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  formatDate(doc.dueDate!),
                  style: pw.TextStyle(fontSize: 10, color: ink),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Table builders ──────────────────────────────────────────────────

  /// One line-items table builder shared by every theme. The [style]
  /// ('striped' | 'bordered' | 'outlined' | 'minimal') controls the
  /// structure; [accent] colours the header band when the style uses one.
  static pw.Widget _buildTable(
    List<LineItem> items,
    String currency,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
    String style, {
    PdfColor? accent,
  }) {
    const headers = ['#', 'DESCRIPTION', 'QTY', 'UNIT PRICE', 'AMOUNT'];
    const alignments = {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
    };
    final hasHeaderFill = style == 'striped' || style == 'bordered';
    final headerBg = hasHeaderFill
        ? (accent ?? PdfColor.fromHex('#334155'))
        : null;
    final bordered = style == 'bordered';
    final minimal = style == 'minimal';
    final surface = PdfColor.fromHex('#f8fafc');

    pw.BoxDecoration cellDeco(int cell, dynamic data, int rowNum) {
      if (bordered) {
        return pw.BoxDecoration(border: pw.Border.all(color: hair, width: 0.4));
      }
      return pw.BoxDecoration(
        color: style == 'striped' && cell.isOdd ? surface : null,
        border: pw.Border(
          bottom: pw.BorderSide(color: hair, width: minimal ? 0.5 : 0.3),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 8,
        color: headerBg != null ? PdfColor.fromHex('#ffffff') : muted,
        letterSpacing: headerBg != null ? 1.5 : (minimal ? 2 : 1.5),
        fontWeight: headerBg != null
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: pw.TextStyle(fontSize: 10, color: ink),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: headerBg != null
          ? pw.BoxDecoration(color: headerBg)
          : pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: ink, width: 0.5)),
            ),
      cellDecoration: cellDeco,
      cellPadding: pw.EdgeInsets.symmetric(
        horizontal: minimal ? 4 : 6,
        vertical: minimal ? 10 : 8,
      ),
      headerPadding: pw.EdgeInsets.symmetric(
        horizontal: minimal ? 4 : 6,
        vertical: minimal ? 6 : 10,
      ),
      headers: headers,
      headerAlignments: alignments,
      cellAlignments: alignments,
      data: items.asMap().entries.map((entry) {
        final li = entry.value;
        return [
          '${entry.key + 1}',
          li.description.isEmpty ? '—' : li.description,
          li.quantity.toStringAsFixed(
            li.quantity == li.quantity.roundToDouble() ? 0 : 2,
          ),
          formatMoney(li.unitPrice, currency),
          formatMoney(rowTotal(li), currency),
        ];
      }).toList(),
    );
  }

  // ── Totals ──────────────────────────────────────────────────────────

  /// The tax-row label for a document. NEVER a fabricated rate: the label
  /// comes from the stored tax rate only when tax was actually charged
  /// (taxAmount > 0). A zero/no-tax document prints no tax row at all —
  /// a non-VAT business's PDF never claims VAT was charged.
  static String? _taxLabel(QuoteflowDocument doc) {
    if (doc.taxAmount <= 0) return null;
    final rate = doc.taxRate;
    if (rate <= 0) return 'Tax';
    return 'Tax (${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%)';
  }

  static pw.Widget _buildTotals(
    QuoteflowDocument doc,
    String currency,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
  ) {
    final taxLabel = _taxLabel(doc);
    return pw.Column(
      children: [
        _totalRow('Subtotal', formatMoney(doc.subtotal, currency), muted, ink),
        if (taxLabel != null)
          _totalRow(taxLabel, formatMoney(doc.taxAmount, currency), muted, ink),
        if (doc.discount > 0)
          _totalRow(
            'Discount',
            '− ${formatMoney(doc.discount, currency)}',
            muted,
            ink,
          ),
        pw.Container(height: 0.5, color: ink),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.Text(
              formatMoney(doc.total, currency),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTotalsBold(
    QuoteflowDocument doc,
    String currency,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
    PdfColor accent,
  ) {
    final taxLabel = _taxLabel(doc);
    return pw.Column(
      children: [
        _totalRow('Subtotal', formatMoney(doc.subtotal, currency), muted, ink),
        if (taxLabel != null)
          _totalRow(taxLabel, formatMoney(doc.taxAmount, currency), muted, ink),
        if (doc.discount > 0)
          _totalRow(
            'Discount',
            '− ${formatMoney(doc.discount, currency)}',
            muted,
            ink,
          ),
        pw.Container(height: 1, color: accent),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.Text(
              formatMoney(doc.total, currency),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Micro-widgets ───────────────────────────────────────────────────

  static pw.Widget _label(String text, PdfColor muted) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 8, color: muted, letterSpacing: 1.5),
    );
  }

  static pw.Widget _boldText(String text, PdfColor ink) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      ),
    );
  }

  static pw.Widget _mutedText(String text, PdfColor muted) {
    return pw.Text(text, style: pw.TextStyle(fontSize: 9, color: muted));
  }

  // ── Organisation detail lines (used on every theme) ───────────────

  static bool _nonBlank(String? v) => v != null && v.trim().isNotEmpty;

  /// Free-form address plus structured city / state / postal / country.
  static String? _orgFullAddress(Organization org) {
    final parts = <String>[];
    if (_nonBlank(org.address)) parts.add(org.address!.trim());
    final loc = [
      org.city,
      org.state,
      org.postalCode,
    ].where(_nonBlank).map((s) => s!.trim()).join(', ');
    if (loc.isNotEmpty) parts.add(loc);
    if (_nonBlank(org.country)) parts.add(org.country!.trim());
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// Registration / tax identifiers as display lines.
  static List<String> _orgIdLines(Organization org) {
    final lines = <String>[];
    final ids = <String>[
      if (_nonBlank(org.registration)) 'Reg ${org.registration!.trim()}',
      if (_nonBlank(org.tin)) 'TIN ${org.tin!.trim()}',
      if (_nonBlank(org.vatNumber)) 'VAT ${org.vatNumber!.trim()}',
      if (_nonBlank(org.duns)) 'DUNS ${org.duns!.trim()}',
    ].join(' · ');
    if (ids.isNotEmpty) lines.add(ids);
    if (_nonBlank(org.praz)) lines.add('PRAZ ${org.praz!.trim()}');
    return lines;
  }

  /// Contact + identifier + address lines for the FROM block.
  static List<String> _orgDetailLines(Organization org) {
    final lines = <String>[];
    if (org.emails.isNotEmpty) lines.add(org.emails.join(' · '));
    if (_nonBlank(org.website)) lines.add(org.website!.trim());
    if (_nonBlank(org.phone)) lines.add(org.phone!.trim());
    lines.addAll(_orgIdLines(org));
    final address = _orgFullAddress(org);
    if (address != null) lines.add(address);
    return lines;
  }

  /// One-line bank summary for the payment footer, or null when no
  /// banking details have been configured.
  static String? _bankSummary(Organization org) {
    final parts = <String>[];
    if (_nonBlank(org.bankName)) parts.add(org.bankName!.trim());
    if (_nonBlank(org.bankBranch)) parts.add(org.bankBranch!.trim());
    if (_nonBlank(org.bankAccountName)) {
      parts.add('A/c name: ${org.bankAccountName!.trim()}');
    }
    if (_nonBlank(org.bankAccountNumber)) {
      parts.add('A/c no: ${org.bankAccountNumber!.trim()}');
    }
    if (_nonBlank(org.bankIban)) parts.add('IBAN: ${org.bankIban!.trim()}');
    if (_nonBlank(org.bankSwift)) parts.add('SWIFT: ${org.bankSwift!.trim()}');
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// True when the document carries a usable signature image.
  static bool _hasSignature(QuoteflowDocument doc) =>
      _nonBlank(doc.signatureData);

  /// Right-aligned signature block placed above the footer on every theme.
  static pw.Widget _signatureBlock(
    QuoteflowDocument doc,
    Organization org,
    PdfColor ink,
    PdfColor muted,
  ) {
    final bytes = _decodeDataUrl(doc.signatureData);
    if (bytes == null) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Image(pw.MemoryImage(bytes), height: 42),
        pw.SizedBox(height: 4),
        pw.Container(width: 170, height: 0.5, color: ink),
        pw.SizedBox(height: 4),
        pw.Text(
          'Authorized signature — ${org.name}',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ],
    );
  }

  /// True when the PDF must carry the ZIMRA fiscal verification section:
  /// only fiscal document types that FDMS actually accepted.
  @visibleForTesting
  static bool fiscalVisible(QuoteflowDocument doc) =>
      doc.isFiscalType && doc.isFiscalised;

  static pw.Widget _fiscalRow(
    String label,
    String value,
    PdfColor muted,
    PdfColor ink,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 108,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8.5, color: muted),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8.5, color: ink),
            ),
          ),
        ],
      ),
    );
  }

  /// ZIMRA fiscal verification section printed near the bottom of every
  /// fiscalised document.
  ///
  /// All values come from the stored fiscalisation result (FDMS-assigned
  /// device/day/receipt numbers); the QR code encodes the exact ZIMRA QR
  /// payload stored with the receipt — never a locally invented code.
  @visibleForTesting
  static pw.Widget fiscalBlock(
    QuoteflowDocument doc,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
  ) {
    final payload = doc.fiscalQrPayload;
    final hasPayload = payload != null && payload.trim().isNotEmpty;
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 28),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: hair, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            doc.fiscalValidationDetails.isEmpty
                ? 'FISCAL DETAILS'
                : doc.fiscalValidationLabel,
            style: pw.TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _fiscalRow(
                      'Fiscal Device ID',
                      '${doc.fiscalDeviceId ?? '—'}',
                      muted,
                      ink,
                    ),
                    _fiscalRow(
                      'Fiscal Day',
                      '${doc.fiscalDayNo ?? '—'}',
                      muted,
                      ink,
                    ),
                    _fiscalRow(
                      'Receipt Number',
                      '${doc.fiscalReceiptNo ?? '—'}',
                      muted,
                      ink,
                    ),
                    _fiscalRow(
                      'Global Receipt No',
                      '${doc.fiscalReceiptGlobalNo ?? '—'}',
                      muted,
                      ink,
                    ),
                    if (doc.fiscalReceiptId != null)
                      _fiscalRow(
                        'ZIMRA Receipt ID',
                        '${doc.fiscalReceiptId}',
                        muted,
                        ink,
                      ),
                    if (hasPayload)
                      pw.UrlLink(
                        destination: payload,
                        child: _fiscalRow(
                          'Verification link',
                          payload,
                          muted,
                          ink,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasPayload) ...[
                pw.SizedBox(width: 8),
                // White background + padding gives the QR its quiet zone.
                pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.BarcodeWidget(
                    data: payload,
                    barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                    ),
                    width: 90,
                    height: 90,
                    color: PdfColors.black,
                    drawText: false,
                  ),
                ),
              ],
            ],
          ),
          if (hasPayload) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Scan the QR code or open the verification link to verify with ZIMRA.',
              style: pw.TextStyle(fontSize: 7.5, color: muted),
            ),
          ],
        ],
      ),
    );
  }

  /// Insert the fiscal verification block after the signature block of a
  /// theme's build list.
  static List<pw.Widget> _buyerFiscalSection(
    QuoteflowDocument doc,
    PdfColor ink,
    PdfColor muted,
  ) {
    final receipt = (doc.fiscalRecord?['request'] as Map?)?['receipt'] as Map?;
    final buyer = receipt?['buyerData'] as Map?;
    if (!doc.isFiscalised || buyer == null) return const [];
    return [
      pw.SizedBox(height: 16),
      pw.Text(
        'BUYER FISCAL DETAILS',
        style: pw.TextStyle(fontSize: 8, color: muted),
      ),
      pw.SizedBox(height: 5),
      for (final key in [
        'buyerRegisterName',
        'buyerTradeName',
        'buyerTIN',
        'vatNumber',
      ])
        if (buyer[key] != null)
          pw.Text(
            (key == 'buyerTIN'
                    ? 'TIN: '
                    : key == 'vatNumber'
                    ? 'VAT: '
                    : '') +
                buyer[key].toString(),
            style: pw.TextStyle(fontSize: 9, color: ink),
          ),
    ];
  }

  static List<pw.Widget> _withFiscalSection(
    QuoteflowDocument doc,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
  ) => [
    ..._buyerFiscalSection(doc, ink, muted),
    if (fiscalVisible(doc)) ...[
      pw.SizedBox(height: 24),
      fiscalBlock(doc, ink, muted, hair),
    ],
  ];

  static pw.Widget _totalRow(
    String label,
    String value,
    PdfColor muted,
    PdfColor ink,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, color: ink)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    Organization org,
    PdfColor ink,
    PdfColor muted,
    PdfColor hair,
  ) {
    const fallback =
        'Bank transfer details to be provided. Please reference document number on payment.';
    final bank = _bankSummary(org);
    final custom = _nonBlank(org.paymentInstructions)
        ? org.paymentInstructions!.trim()
        : null;
    final paymentText =
        custom ?? (bank != null ? 'Payment details: $bank' : fallback);

    final rows = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: custom != null
                        ? 'Payment instructions: '
                        : 'Payment: ',
                    style: pw.TextStyle(fontSize: 8, color: muted),
                  ),
                  pw.TextSpan(
                    text: paymentText,
                    style: pw.TextStyle(fontSize: 8, color: ink),
                  ),
                ],
              ),
            ),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
    ];
    // When both a custom message and real bank details exist, show both.
    if (custom != null && bank != null) {
      rows.add(pw.SizedBox(height: 3));
      rows.add(
        pw.Text('Bank: $bank', style: pw.TextStyle(fontSize: 8, color: muted)),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Column(
        children: [
          pw.Container(height: 0.5, color: hair),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  static Future<void> previewPdf(Uint8List bytes, String docNumber) async {
    await Printing.layoutPdf(onLayout: (_) => bytes, name: '$docNumber.pdf');
  }

  static Future<void> sharePdf(Uint8List bytes, String docNumber) async {
    await Printing.sharePdf(bytes: bytes, filename: '$docNumber.pdf');
  }
}
