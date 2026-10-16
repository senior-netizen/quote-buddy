part of 'pdf_service.dart';

/// Reference-inspired layouts share the existing totals, tax and fiscal data.
/// No sample text, payment method, signature or QR is invented by a theme.
extension _ReferenceThemes on PdfService {
  static Future<Uint8List> generate({
    required QuoteflowDocument doc,
    required Client? client,
    required Organization org,
  }) async {
    if (org.pdfTheme == 'boutique') return _receipt(doc, client, org);
    final mono = org.pdfTheme == 'editorial' || org.pdfTheme == 'ledger';
    final ledger = org.pdfTheme == 'ledger';
    final studio = org.pdfTheme == 'studio';
    final accent = PdfColor.fromHex(studio ? '#EC6033' : '#FF8900');
    final ink = PdfColor.fromHex('#222326');
    final muted = PdfColor.fromHex('#55565A');
    final hair = PdfColor.fromHex(mono ? '#555555' : '#D5D5D5');
    final fonts = await PdfService._loadFonts();
    final theme = mono
        ? pw.ThemeData.withFont(
            base: pw.Font.courier(),
            bold: pw.Font.courierBold(),
            italic: pw.Font.courierOblique(),
          )
        : fonts.theme;
    final pdf = pw.Document();
    pw.Widget title() => pw.Text(
      doc.type.label.toUpperCase(),
      style: pw.TextStyle(
        font: fonts.bold,
        fontSize: mono ? 30 : 38,
        color: ink,
      ),
    );
    pw.Widget seller() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfService._headerLogo(
          org,
          mono ? ink : accent,
          fonts,
          height: _logoSize(org),
        ),
        pw.SizedBox(height: 8),
        ...PdfService._orgDetailLines(org).map(
          (line) =>
              pw.Text(line, style: pw.TextStyle(fontSize: 8, color: muted)),
        ),
      ],
    );
    pw.Widget metadata({bool white = false}) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${doc.type.label} No. ${doc.docNumber}',
          style: pw.TextStyle(
            fontSize: 9,
            color: white ? PdfColors.white : ink,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Date: ${formatDate(doc.issueDate)}',
          style: pw.TextStyle(
            fontSize: 9,
            color: white ? PdfColors.white : ink,
          ),
        ),
        if (doc.dueDate != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            'Due: ${formatDate(doc.dueDate!)}',
            style: pw.TextStyle(
              fontSize: 9,
              color: white ? PdfColors.white : ink,
            ),
          ),
        ],
      ],
    );
    pw.Widget buyer({bool white = false}) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BILLED TO',
          style: pw.TextStyle(
            fontSize: 8,
            color: white ? PdfColors.white : muted,
          ),
        ),
        pw.SizedBox(height: 7),
        pw.Text(
          client?.companyName ?? 'Walk-in customer',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: white ? PdfColors.white : ink,
          ),
        ),
        if (client != null) ...[
          if (client.formattedAddress.isNotEmpty)
            pw.Text(
              client.formattedAddress,
              style: pw.TextStyle(
                fontSize: 9,
                color: white ? PdfColors.white : muted,
              ),
            ),
          for (final contact in [
            client.phone,
            client.email,
          ].whereType<String>())
            pw.Text(
              contact,
              style: pw.TextStyle(
                fontSize: 9,
                color: white ? PdfColors.white : muted,
              ),
            ),
        ],
      ],
    );
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(38),
          theme: theme,
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              color: mono ? PdfColor.fromHex('#F5F2ED') : PdfColors.white,
            ),
          ),
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Container(height: mono ? 0.5 : 3, color: mono ? hair : accent),
            pw.SizedBox(height: 9),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Thank you for your business.',
                  style: pw.TextStyle(fontSize: 8, color: muted),
                ),
                pw.Text(
                  '${doc.docNumber}  /  ${ctx.pageNumber}',
                  style: pw.TextStyle(fontSize: 8, color: muted),
                ),
              ],
            ),
          ],
        ),
        build: (_) => [
          if (mono) ...[
            if (!ledger)
              pw.Align(alignment: pw.Alignment.centerRight, child: title()),
            if (!ledger) pw.SizedBox(height: 26),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: seller()),
                pw.SizedBox(width: 30),
                pw.Expanded(child: metadata()),
              ],
            ),
            pw.SizedBox(height: ledger ? 35 : 24),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 14),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: hair, width: .5),
                  bottom: pw.BorderSide(color: hair, width: .5),
                ),
              ),
              child: buyer(),
            ),
            pw.SizedBox(height: 38),
          ] else if (studio) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: seller()),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: title(),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(22),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: const pw.BorderRadius.only(
                  topRight: pw.Radius.circular(28),
                  bottomLeft: pw.Radius.circular(28),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: metadata(white: true)),
                  pw.SizedBox(width: 24),
                  pw.Expanded(child: buyer(white: true)),
                ],
              ),
            ),
            pw.SizedBox(height: 26),
          ] else ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: title()),
                pw.SizedBox(width: 24),
                pw.Expanded(child: seller()),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              color: accent,
              child: metadata(),
            ),
            pw.SizedBox(height: 22),
            buyer(),
            pw.SizedBox(height: 24),
            pw.Text(
              'Details',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
          ],
          PdfService._buildTable(
            doc.lineItems,
            org.currency,
            ink,
            muted,
            hair,
            effectiveTableStyle(org.pdfTheme, org.tableStyle),
            accent: mono ? ink : accent,
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 230,
              child: PdfService._buildTotals(
                doc,
                org.currency,
                ink,
                muted,
                hair,
              ),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Container(height: .5, color: hair),
          pw.SizedBox(height: 18),
          if (PdfService._bankSummary(org) != null ||
              PdfService._nonBlank(org.paymentInstructions)) ...[
            pw.Text(
              'PAYMENT DETAILS',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (PdfService._bankSummary(org) case final String bank)
              pw.Text(bank, style: const pw.TextStyle(fontSize: 9)),
            if (PdfService._nonBlank(org.paymentInstructions))
              pw.Text(
                org.paymentInstructions!,
                style: const pw.TextStyle(fontSize: 9),
              ),
            pw.SizedBox(height: 18),
          ],
          if (PdfService._nonBlank(doc.notes)) ...[
            pw.Text(doc.notes!, style: pw.TextStyle(fontSize: 9, color: muted)),
            pw.SizedBox(height: 18),
          ],
          if (ledger) title(),
          if (PdfService._hasSignature(doc))
            PdfService._signatureBlock(doc, org, ink, muted),
          ...PdfService._withFiscalSection(doc, ink, muted, hair),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _receipt(
    QuoteflowDocument doc,
    Client? client,
    Organization org,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfService._loadFonts();
    final ink = PdfColor.fromHex('#242424');
    final muted = PdfColor.fromHex('#666666');
    final hair = PdfColor.fromHex('#CCCCCC');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          260 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(15),
        theme: fonts.theme,
        footer: (ctx) => pw.Center(
          child: pw.Text(
            '${doc.docNumber} / ${ctx.pageNumber}',
            style: pw.TextStyle(fontSize: 7, color: muted),
          ),
        ),
        build: (_) => [
          PdfService._headerLogo(
            org,
            ink,
            fonts,
            height: _logoSize(org).clamp(20, 40),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Thank you for your business!',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 9),
          pw.Text(
            '${doc.type.label} ${doc.docNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            formatDate(doc.issueDate),
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
          if (client != null)
            pw.Text(client.companyName, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 15),
          pw.Divider(color: hair, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 10),
          for (final (index, item) in doc.lineItems.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 9),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 16,
                    child: pw.Text(
                      '${index + 1}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.description,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 7),
                        pw.Text(
                          '${item.quantity} x ${formatMoney(item.unitPrice, org.currency)}',
                          style: pw.TextStyle(fontSize: 8, color: muted),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 7),
                  pw.SizedBox(
                    width: 61,
                    child: pw.Text(
                      formatMoney(item.total, org.currency),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColor.fromHex('#F1F1F1'),
            child: PdfService._buildTotals(doc, org.currency, ink, muted, hair),
          ),
          if (PdfService._nonBlank(doc.notes)) ...[
            pw.SizedBox(height: 18),
            pw.Text(doc.notes!, style: const pw.TextStyle(fontSize: 8)),
          ],
          if (PdfService._nonBlank(org.paymentInstructions)) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              org.paymentInstructions!,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          ...PdfService._buyerFiscalSection(doc, ink, muted),
          if (PdfService.fiscalVisible(doc)) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              doc.fiscalValidationLabel,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            for (final detail in doc.fiscalValidationDetails)
              pw.Text(detail, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 6),
            pw.Text(
              'Device ${doc.fiscalDeviceId} / Day ${doc.fiscalDayNo}\nReceipt ${doc.fiscalReceiptNo} / Global ${doc.fiscalReceiptGlobalNo}\nZIMRA ID ${doc.fiscalReceiptId ?? "-"}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            if (doc.fiscalQrPayload?.isNotEmpty == true) ...[
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.BarcodeWidget(
                    data: doc.fiscalQrPayload!,
                    barcode: pw.Barcode.qrCode(),
                    width: 85,
                    height: 85,
                    drawText: false,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Scan to verify with ZIMRA',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ],
          pw.SizedBox(height: 20),
          pw.Divider(color: hair),
          pw.Text(org.name, style: const pw.TextStyle(fontSize: 8)),
          ...PdfService._orgDetailLines(org).map(
            (line) =>
                pw.Text(line, style: pw.TextStyle(fontSize: 7, color: muted)),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}
