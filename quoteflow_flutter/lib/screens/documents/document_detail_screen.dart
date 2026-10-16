import '../../services/fiscal_buyer_mapper.dart';
import '../../widgets/customer_fiscal_details.dart';
import '../../widgets/customer_form.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/client.dart';
import '../../models/document.dart';
import '../../models/organization.dart';
import '../../providers/document_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/zimra_provider.dart';
import '../../services/calculations.dart';
import '../../services/fiscalisation.dart';
import '../../services/zimra/zimra.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_service.dart';
import '../../widgets/document_form_screen.dart';
import '../../widgets/document_pdf_style_sheet.dart';
import '../../widgets/signature_pad.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  /// Guards the fiscalise button against double-taps while submitting.
  bool _fiscalising = false;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;
    final pad = isNarrow ? 16.0 : 24.0;

    return Consumer<DocumentProvider>(
      builder: (context, docProvider, _) {
        final doc = docProvider.getDocument(widget.documentId);
        if (doc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Document')),
            body: const Center(child: Text('Document not found')),
          );
        }

        final client = docProvider.getClientForDocument(doc.clientId);
        // Watch (not read): the PDF theme, logo and table style live on the
        // organization. A read here captured a stale org, so a theme chosen
        // in Settings was never applied to PDFs rendered from this screen.
        final org = context.watch<OrganizationProvider>().organization;
        final currency = org.currency;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              doc.docNumber,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            actions: [
              if (doc.type == DocumentType.quote)
                isNarrow
                    ? IconButton(
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        tooltip: 'Convert to Invoice',
                        onPressed: () =>
                            _convertToInvoice(context, doc, docProvider),
                      )
                    : TextButton.icon(
                        onPressed: () =>
                            _convertToInvoice(context, doc, docProvider),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Convert to Invoice'),
                      ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    if (doc.isFiscalised || doc.isFiscalPending) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentFormScreen(editDoc: doc),
                      ),
                    );
                  } else if (value == 'duplicate') {
                    _duplicateDocument(context, doc, docProvider);
                  } else if (value == 'delete') {
                    _deleteDocument(context, doc, docProvider);
                  } else if (value == 'pdf') {
                    _previewPdf(context, doc, docProvider, org);
                  } else if (value == 'share') {
                    _sharePdf(context, doc, docProvider, org);
                  }
                },
                itemBuilder: (context) => [
                  if (!doc.isFiscalised && !doc.isFiscalPending)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  const PopupMenuItem(value: 'pdf', child: Text('Preview PDF')),
                  const PopupMenuItem(value: 'share', child: Text('Share PDF')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type & status header with status dropdown
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        doc.type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status dropdown
                    _StatusDropdown(doc: doc),
                  ],
                ),

                const SizedBox(height: 16),

                // Client info
                if (client != null) ...[
                  _sectionTitle('BILLED TO'),
                  const SizedBox(height: 8),
                  _infoCard(
                    context,
                    children: [
                      _infoRow('Company', client.companyName),
                      if (client.address != null)
                        _infoRow('Address', client.address!),
                      if (client.email != null)
                        _infoRow('Email', client.email!),
                      if (client.phone != null)
                        _infoRow('Phone', client.phone!),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Dates
                isNarrow
                    ? Column(
                        children: [
                          _dateCardFull(
                            'ISSUE DATE',
                            formatDate(doc.issueDate),
                          ),
                          const SizedBox(height: 8),
                          _dateCardFull(
                            doc.type == DocumentType.invoice ||
                                    doc.type == DocumentType.creditNote
                                ? 'DUE DATE'
                                : 'VALID UNTIL',
                            doc.dueDate != null
                                ? formatDate(doc.dueDate!)
                                : '—',
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _dateCard(
                              'ISSUE DATE',
                              formatDate(doc.issueDate),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateCard(
                              doc.type == DocumentType.invoice ||
                                      doc.type == DocumentType.creditNote
                                  ? 'DUE DATE'
                                  : 'VALID UNTIL',
                              doc.dueDate != null
                                  ? formatDate(doc.dueDate!)
                                  : '—',
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 24),

                // Line items
                _sectionTitle('LINE ITEMS'),
                const SizedBox(height: 8),
                isNarrow
                    ? _buildLineItemsCards(doc.lineItems, currency)
                    : _buildLineItemsTable(doc.lineItems, currency),

                const SizedBox(height: 20),

                // Totals
                _sectionTitle('TOTALS'),
                const SizedBox(height: 8),
                _totalsCard(doc, currency),

                // Notes
                if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('NOTES'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doc.notes!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Total summary card
                _totalSummaryCard(doc, currency),

                // ZIMRA fiscalisation (fiscal document types only)
                if (doc.isFiscalType) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('FISCALISATION'),
                  const SizedBox(height: 8),
                  _fiscalCard(context, doc, docProvider, org, client),
                ],

                const SizedBox(height: 24),

                // Signature
                _sectionTitle('SIGNATURE'),
                const SizedBox(height: 8),
                _signatureCard(context, doc, docProvider),

                const SizedBox(height: 24),

                // PDF style
                _sectionTitle('PDF STYLE'),
                const SizedBox(height: 8),
                _pdfStyleCard(context, doc, docProvider, org),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _convertToInvoice(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final newDoc = await docProvider.convertToInvoice(doc);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Converted to invoice')));
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(documentId: newDoc.id),
        ),
      );
    }
  }

  void _duplicateDocument(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final newDoc = await docProvider.duplicateDocument(doc);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document duplicated')));
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(documentId: newDoc.id),
        ),
      );
    }
  }

  void _deleteDocument(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('This will permanently delete ${doc.docNumber}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await docProvider.deleteDocument(doc.id);
      Navigator.of(context).pop();
    }
  }

  Future<void> _previewPdf(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    org,
  ) async {
    final client = docProvider.getClientForDocument(doc.clientId);
    try {
      final bytes = await PdfService.generatePdf(
        doc: doc,
        client: client,
        org: org,
      );
      if (!context.mounted) return;
      // Render the real PDF in-app with the printing package's preview,
      // which also offers print and share actions.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.92,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.docNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (_) async => bytes,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    allowPrinting: true,
                    allowSharing: true,
                    pdfFileName: '${doc.docNumber}.pdf',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF failed: $e')));
      }
    }
  }

  Future<void> _sharePdf(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    org,
  ) async {
    final client = docProvider.getClientForDocument(doc.clientId);
    try {
      final bytes = await PdfService.generatePdf(
        doc: doc,
        client: client,
        org: org,
      );
      await PdfService.sharePdf(bytes, doc.docNumber);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ── ZIMRA fiscalisation ───────────────────────────────────────────────

  /// Reactive access, valid only while building.
  ZimraProvider? _zimraWatch(BuildContext context) {
    try {
      return context.watch<ZimraProvider>();
    } catch (_) {
      return null; // Harness without the ZIMRA provider (unit/widget tests).
    }
  }

  /// Non-reactive access for event handlers.
  ZimraProvider? _zimraRead(BuildContext context) {
    try {
      return context.read<ZimraProvider>();
    } catch (_) {
      return null;
    }
  }

  void _fiscalMsg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  /// Compact fiscalisation section: status, FDMS numbers, the ZIMRA
  /// verification payload and its QR code — plus the action buttons.
  Widget _fiscalCard(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    Organization org,
    Client? client,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final zimra = _zimraWatch(context);
    final payload = doc.fiscalQrPayload;

    final surface = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _fiscalContent(
        context,
        doc,
        docProvider,
        org,
        client,
        zimra,
        payload,
      ),
    );
    return surface;
  }

  Widget _fiscalContent(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    Organization org,
    Client? client,
    ZimraProvider? zimra,
    String? payload,
  ) {
    final scheme = Theme.of(context).colorScheme;

    if (doc.isFiscalised) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                doc.fiscalValidationDetails.isEmpty
                    ? Icons.verified
                    : Icons.warning_amber,
                color: doc.fiscalValidationDetails.isEmpty
                    ? Colors.green
                    : scheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doc.fiscalValidationLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: doc.fiscalValidationDetails.isEmpty
                        ? Colors.green.shade800
                        : scheme.error,
                  ),
                ),
              ),
              if (doc.fiscalisedAt != null)
                Text(
                  formatDate(doc.fiscalisedAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final detail in doc.fiscalValidationDetails)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(detail),
            ),
          _infoRow('Device ID', '${doc.fiscalDeviceId ?? '—'}'),
          _infoRow('Fiscal Day', '${doc.fiscalDayNo ?? '—'}'),
          _infoRow('Receipt Number', '${doc.fiscalReceiptNo ?? '—'}'),
          _infoRow('Global Receipt No', '${doc.fiscalReceiptGlobalNo ?? '—'}'),
          if (doc.fiscalReceiptId != null)
            _infoRow('ZIMRA Receipt ID', '${doc.fiscalReceiptId}'),
          const SizedBox(height: 8),
          if (payload != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEVICE VERIFICATION',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        payload,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scan to verify this receipt',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                QrImageView(
                  data: payload,
                  size: 104,
                  backgroundColor: Colors.white,
                ),
              ],
            )
          else
            Text(
              'No verification QR payload was recorded with this receipt.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
        ],
      );
    }

    if (doc.isFiscalPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending fiscalisation',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The receipt was signed but not yet accepted by FDMS (network '
            'unavailable). Retry when the device is online — the same '
            'receipt is resubmitted, so no new receipt number is consumed.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _fiscalising
                ? null
                : () => _retryFiscalPending(context, doc, docProvider),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Retry fiscalisation'),
          ),
        ],
      );
    }

    // Not fiscalised, or rejected by FDMS.
    final rejected = doc.isFiscalRejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              rejected ? Icons.error_outline : Icons.radio_button_unchecked,
              color: rejected ? scheme.error : scheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              rejected ? 'Fiscalisation failed' : 'Not fiscalised',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: rejected ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (rejected && doc.fiscalError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              doc.fiscalError!,
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _fiscalHint(zimra),
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        CustomerFiscalDetails(
          customer: client,
          include: doc.includeBuyerDetails,
          onChanged: (value) async {
            doc.includeBuyerDetails = value;
            await docProvider.saveFiscalisation(doc);
          },
          onEdited: () {
            if (mounted) setState(() {});
          },
        ),
        if (zimra != null && zimra.isRegistered && zimra.isOpen) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _fiscalising
                ? null
                : () => _fiscalise(context, doc, docProvider, org, client),
            icon: _fiscalising
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user, size: 16),
            label: Text(
              rejected ? 'Try fiscalising again' : 'Fiscalise with ZIMRA',
            ),
          ),
        ],
      ],
    );
  }

  String _fiscalHint(ZimraProvider? zimra) {
    if (zimra == null || !zimra.isRegistered) {
      return 'Register a ZIMRA device in Settings → Organization → ZIMRA FDMS '
          'before fiscalising this document.';
    }
    if (!zimra.isOpen) {
      return 'No fiscal day is open. Open one in Settings → ZIMRA FDMS '
          'before fiscalising this document.';
    }
    return 'Submitting fiscalises this document with ZIMRA FDMS. The '
        'verification QR code and fiscal numbers are stored for reprints.';
  }

  /// Pick how the document is settled (FDMS `moneyTypeCode`).
  Future<String?> _pickMoneyType(DocumentType type) async {
    final initial = defaultFiscalMoneyType(type);
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Payment method'),
        children: [
          for (final mt in fiscalMoneyTypes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mt),
              child: Text(mt == initial ? '$mt (default)' : mt),
            ),
        ],
      ),
    );
  }

  Future<void> _fiscalise(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    Organization org,
    Client? client,
  ) async {
    if (_fiscalising) return;
    setState(() => _fiscalising = true);
    try {
      await _fiscaliseLocked(context, doc, docProvider, org, client);
    } finally {
      if (mounted) setState(() => _fiscalising = false);
    }
  }

  Future<void> _fiscaliseLocked(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    Organization org,
    Client? client,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final zimra = _zimraRead(context);
    if (zimra == null || !zimra.isRegistered) {
      _fiscalMsg('Register a ZIMRA device first.', error: true);
      return;
    }
    if (!zimra.isOpen) {
      _fiscalMsg('Open a fiscal day first.', error: true);
      return;
    }

    zimra.clearSubmitError();

    // Idempotency: an already-fiscalised document is never submitted twice
    // (rapid double-taps, crash-retry, duplicate flush). The caller sees
    // the existing fiscal record instead.
    final existing = guardDoubleFiscalisation(doc);
    if (existing != null) {
      _fiscalMsg(
        'Already fiscalised — receipt number ${doc.fiscalReceiptNo ?? ''}. '
        'Fiscalisation skipped.',
      );
      return;
    }

    BuyerData? buyer;
    while (true) {
      try {
        buyer = FiscalBuyerMapper.map(
          docProvider.getClientForDocument(doc.clientId),
          include: doc.includeBuyerDetails,
        );
        break;
      } on FiscalBuyerException catch (error) {
        if (!context.mounted) return;
        final edit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Customer fiscal details are incomplete'),
            content: Text(error.problems.map((p) => '• $p').join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Edit Customer'),
              ),
            ],
          ),
        );
        if (edit != true || !context.mounted) return;
        final current = docProvider.getClientForDocument(doc.clientId);
        if (current == null) {
          // The document's customer was deleted after the toggle was
          // enabled — there is nothing to edit. Explain instead of silently
          // aborting (which left the user stuck on a dead-end dialog).
          _fiscalMsg(
            'This document\'s customer no longer exists. Re-select a '
            'customer in the document editor, or switch off "Include '
            'customer fiscal details".',
            error: true,
          );
          return;
        }
        final saved = await showCustomerForm(context, customer: current);
        if (saved == null || !context.mounted) return;
      }
    }

    // Refresh GetConfig before resolving a new receipt. Fail closed on failure.
    var config = await zimra.fetchConfig();
    if (!mounted) return;
    if (config == null) {
      _fiscalMsg(
        zimra.error ?? 'Could not refresh the FDMS configuration.',
        error: true,
      );
      return;
    }
    final cfgProblem = fiscalConfigProblem(config);
    if (cfgProblem != null) {
      _fiscalMsg(cfgProblem, error: true);
      return;
    }

    final moneyType = await _pickMoneyType(doc.type);
    if (moneyType == null) return;

    // Preflight: everything the FDMS contract needs, checked locally —
    // items, device, day state, currency, lines, totals reconciliation,
    // and the ZIMRA tax mapping for every line.
    var preflight = validateFiscalisation(doc: doc, org: org, zimra: zimra);
    if (!preflight.ok &&
        preflight.error!.code == FiscalPreflightCode.taxMappingNotFound) {
      // Stale/missing tax configuration: refresh ONCE automatically, then
      // retry. Never submit an unmapped document.
      fiscalAuditLog('ZIMRA_TAX_RESOLUTION', {
        'invoiceId': doc.id,
        'stage': 'initial-miss',
        'treatment': preflight.error!.invoiceTaxTreatment?.name,
        'rate': preflight.error!.invoiceTaxRate,
      });
      final refreshed = await zimra.fetchConfig();
      if (refreshed != null) {
        preflight = validateFiscalisation(doc: doc, org: org, zimra: zimra);
      }
    }
    if (!preflight.ok) {
      final handled = await _handlePreflightFailure(
        context,
        doc,
        org,
        preflight.error!,
        zimra,
      );
      if (!handled) return;
      preflight = validateFiscalisation(doc: doc, org: org, zimra: zimra);
      if (!preflight.ok) {
        _fiscalMsg(preflight.error!.message, error: true);
        return;
      }
    }
    fiscalAuditLog('ZIMRA_TAX_RESOLUTION', {
      'invoiceId': doc.id,
      'stage': 'resolved',
      'treatments': preflight.treatments.map((t) => t.name).join('+'),
    });

    // Build the receipt lines from the validated treatment/rate lists.
    config = zimra.effectiveConfig ?? config;
    final linesResult = buildFiscalLines(doc: doc, config: config, org: org);
    if (!linesResult.ok) {
      _fiscalMsg(linesResult.problem!, error: true);
      return;
    }

    final totalCents = fiscalTotalCents(linesResult.lines);
    if (totalCents != (doc.total * 100).round()) {
      _fiscalMsg(
        'FDMS receipt total does not match the document. Review tax settings and re-save the document.',
        error: true,
      );
      return;
    }
    var original = doc.convertedFrom != null
        ? docProvider.getDocument(doc.convertedFrom!)
        : null;
    final isNote =
        doc.type == DocumentType.creditNote ||
        doc.type == DocumentType.debitNote;
    bool eligible(QuoteflowDocument candidate) =>
        candidate.type == DocumentType.invoice &&
        candidate.orgId == doc.orgId &&
        candidate.clientId == doc.clientId &&
        candidate.isFiscalised &&
        fiscalOriginalReference(
              doc: doc,
              deviceId: zimra.identity?.deviceId ?? 0,
              original: candidate,
            ) !=
            null;
    if (isNote && (original == null || !eligible(original))) {
      final invoices = docProvider.allDocuments.where(eligible).toList();
      if (invoices.isEmpty) {
        _fiscalMsg(
          'This note needs an original fiscalised invoice for the same customer and business. Fiscalise the original invoice first.',
          error: true,
        );
        return;
      }
      if (!context.mounted) return;
      original = await showDialog<QuoteflowDocument>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select original fiscal invoice'),
          children: invoices
              .map(
                (invoice) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, invoice),
                  child: ListTile(
                    title: Text(invoice.docNumber),
                    subtitle: Text(
                      'Fiscal receipt ${invoice.fiscalReceiptId ?? invoice.fiscalReceiptGlobalNo}',
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (original == null) return;
      doc.convertedFrom = original.id;
      await docProvider.updateDocument(doc);
    }

    fiscalAuditLog('ZIMRA_FISCALISATION_STARTED', {
      'invoiceId': doc.id,
      'deviceId': zimra.identity?.deviceId,
      'docNumber': doc.docNumber,
    });
    final result = await zimra.submitReceipt(
      currency: org.currency.toUpperCase(),
      invoiceNo: doc.docNumber,
      lines: linesResult.lines,
      payments: [ReceiptPayment(moneyType: moneyType, amount: totalCents)],
      receiptType: fiscalReceiptType(doc.type),
      linesTaxInclusive: false,
      notes: doc.notes,
      // The buyer mapped and validated above — the customer's saved TIN/VAT
      // reach FDMS exactly as stored. Never replace this with a name-only
      // BuyerData: that strips the TIN and fails FDMS buyer validation.
      buyer: buyer,
      creditDebitNote: fiscalOriginalReference(
        doc: doc,
        deviceId: zimra.identity?.deviceId ?? 0,
        original: original,
      ),
      receiptPrintForm: doc.type == DocumentType.receipt
          ? 'Receipt48'
          : 'InvoiceA4',
    );
    if (result != null) {
      applyFiscalisation(
        doc,
        deviceId: zimra.identity!.deviceId,
        fiscalDayNo: zimra.dayState.fiscalDayNo,
        result: result,
        qrPayload: result.qrData,
        taxSnapshot: buildFiscalTaxSnapshot(
          treatments: preflight.treatments,
          rates: preflight.rates,
          lines: linesResult.lines,
        ),
      );
      await docProvider.saveFiscalisation(doc);
      fiscalAuditLog('ZIMRA_FISCALISATION_SUCCESS', {
        'invoiceId': doc.id,
        'deviceId': zimra.identity!.deviceId,
        'receiptId': doc.fiscalReceiptId,
        'receiptGlobalNo': doc.fiscalReceiptGlobalNo,
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${doc.fiscalValidationLabel} — receipt number ${doc.fiscalReceiptNo ?? ''}',
          ),
        ),
      );
      return;
    }

    final failure = zimra.lastSubmitError;
    if (failure != null &&
        failure.code == 'RCP030' &&
        failure.receiptPayload != null) {
      final record = PendingFiscalRecord.fromPayload(
        deviceId: zimra.identity!.deviceId,
        fiscalDayNo: zimra.dayState.fiscalDayNo,
        receiptPayload: failure.receiptPayload!,
      );
      markFiscalPending(doc, record: record);
      await docProvider.saveFiscalisation(doc);
      _fiscalMsg(
        'Network unavailable — receipt signed and saved. Retry fiscalisation '
        'when the device is back online.',
      );
      return;
    }

    final detail = failure?.message ?? zimra.error ?? 'Unknown FDMS error.';
    markFiscalRejected(doc, detail);
    await docProvider.saveFiscalisation(doc);
    fiscalAuditLog('ZIMRA_FISCALISATION_FAILED', {
      'invoiceId': doc.id,
      'deviceId': zimra.identity?.deviceId,
      'errorCode': failure?.code,
    });
    _fiscalMsg('Fiscalisation failed: $detail', error: true);
  }

  /// Explain a preflight failure in plain language. For tax-mapping
  /// failures this offers a one-tap configuration refresh and retries;
  /// returns true only when the user chose to retry AND a mapping now
  /// exists (verified by the caller's re-preflight).
  Future<bool> _handlePreflightFailure(
    BuildContext context,
    QuoteflowDocument doc,
    Organization org,
    FiscalPreflightError error,
    ZimraProvider zimra,
  ) async {
    if (error.code != FiscalPreflightCode.taxMappingNotFound) {
      _fiscalMsg(error.message, error: true);
      return false;
    }

    if (!mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tax configuration needs updating'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (ctx) {
                final rate = error.invoiceTaxRate;
                final rateText = rate == null
                    ? ''
                    : ' (${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%)';
                return Text(
                  'This invoice uses ${error.invoiceTaxTreatment?.label ?? 'a tax treatment'}'
                  '$rateText, but QuoteFlow could not find a matching tax '
                  'configuration for your ZIMRA fiscal device.',
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Refreshing reads the current tax table from ZIMRA. If it '
              'still lists no matching tax, this document cannot be '
              'fiscalised as-is.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            if (error.configurationLastUpdated != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last synced '
                '${error.configurationLastUpdated!.toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh ZIMRA configuration'),
          ),
        ],
      ),
    );
    if (retry != true) return false;

    // Refresh + re-resolve once. One automatic refresh already ran before
    // this dialog; this is the user-requested second pass, then we stop.
    await zimra.fetchConfig();
    return true;
  }

  Future<void> _retryFiscalPending(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final zimra = _zimraRead(context);
    if (guardDoubleFiscalisation(doc) != null) return;
    final record = PendingFiscalRecord.decode(doc.fiscalPendingPayload);
    if (record == null) {
      markFiscalRejected(
        doc,
        'The pending fiscal record is missing — fiscalise the document '
        'again.',
      );
      await docProvider.saveFiscalisation(doc);
      return;
    }
    if (zimra == null || !zimra.isRegistered) {
      _fiscalMsg('Register a ZIMRA device first.', error: true);
      return;
    }

    zimra.clearSubmitError();
    var config = zimra.effectiveConfig ?? await zimra.fetchConfig();
    if (config == null) {
      _fiscalMsg(
        zimra.error ?? 'Could not load the FDMS configuration.',
        error: true,
      );
      return;
    }
    final cfgProblem = fiscalConfigProblem(config);
    if (cfgProblem != null) {
      _fiscalMsg(cfgProblem, error: true);
      return;
    }

    setState(() => _fiscalising = true);
    final result = await zimra.resubmitReceipt(record.payload);
    if (mounted) setState(() => _fiscalising = false);

    if (result != null) {
      applyFiscalisation(
        doc,
        deviceId: record.deviceId,
        fiscalDayNo: record.fiscalDayNo,
        result: result,
        qrPayload: result.qrData ?? record.qrPayload(config.qrUrl),
      );
      await docProvider.saveFiscalisation(doc);
      _fiscalMsg('Fiscalised — receipt number ${doc.fiscalReceiptNo ?? ''}');
      return;
    }

    if (zimra.lastSubmitError != null) {
      // FDMS actively rejected the stored receipt.
      markFiscalRejected(doc, zimra.lastSubmitError!.message);
      await docProvider.saveFiscalisation(doc);
      _fiscalMsg(
        'Fiscalisation failed: ${zimra.lastSubmitError!.message}',
        error: true,
      );
    } else {
      // Still unreachable — stay pending, same payload kept for next retry.
      _fiscalMsg(
        'Still offline — keep the device connected and retry.',
        error: true,
      );
    }
  }

  // ── Signature ───────────────────────────────────────────────────────

  Widget _signatureCard(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hasSignature =
        doc.signatureData != null && doc.signatureData!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasSignature
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _signaturePreview(doc.signatureData!)),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Re-sign',
                      onPressed: () => _sign(context, doc, docProvider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove signature',
                      onPressed: () =>
                          _removeSignature(context, doc, docProvider),
                    ),
                  ],
                ),
                if (doc.signedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Signed ${formatDate(doc.signedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.draw_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  'No signature yet',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _sign(context, doc, docProvider),
                  icon: const Icon(Icons.draw),
                  label: const Text('Sign this document'),
                ),
              ],
            ),
    );
  }

  Widget _signaturePreview(String dataUrl) {
    if (dataUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(dataUrl.split(',').last);
        return Image.memory(
          bytes,
          height: 64,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      } catch (_) {}
    }
    return const SizedBox();
  }

  Future<void> _sign(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final dataUrl = await showSignaturePad(context);
    if (dataUrl != null) {
      await docProvider.updateDocumentSignature(doc.id, dataUrl);
    }
  }

  Future<void> _removeSignature(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove signature?'),
        content: const Text(
          'The signature will be removed from this document and its PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await docProvider.updateDocumentSignature(doc.id, null);
    }
  }

  // ── PDF style ───────────────────────────────────────────────────────

  Widget _pdfStyleCard(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    org,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final effTheme = doc.pdfTheme ?? org.pdfTheme;
    final effPos = doc.logoPosition ?? org.logoPosition;
    final effTable = effectiveTableStyle(
      effTheme,
      doc.tableStyle ?? org.tableStyle,
    );
    final hasOverride =
        doc.pdfTheme != null ||
        doc.logoPosition != null ||
        doc.tableStyle != null;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Theme', pdfThemeLabel(effTheme)),
          row('Logo position', effPos == 'right' ? 'Right' : 'Left'),
          row('Table style', tableStyleLabel(effTable)),
          if (hasOverride) ...[
            const SizedBox(height: 4),
            Text(
              'Custom style for this document only',
              style: TextStyle(fontSize: 11, color: scheme.primary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openPdfStyleSheet(context, doc, docProvider),
                icon: const Icon(Icons.palette_outlined, size: 16),
                label: const Text('Customize'),
              ),
              TextButton.icon(
                onPressed: () => _copyPdfStyle(context, doc, docProvider, org),
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: const Text('Copy style…'),
              ),
              if (hasOverride) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await docProvider.clearDocumentPdfOverrides(doc.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Using company PDF defaults again'),
                        ),
                      );
                    }
                  },
                  child: const Text('Use company defaults'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfStyleSheet(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) async {
    final result = await showModalBottomSheet<PdfStyleResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DocumentPdfStyleSheet(doc: doc),
      ),
    );
    if (result == null || !context.mounted) return;
    await docProvider.updateDocumentPdfStyle(
      doc.id,
      pdfTheme: result.pdfTheme,
      logoPosition: result.logoPosition,
      tableStyle: result.tableStyle,
    );
  }

  /// Copy this document's effective PDF style onto another document.
  Future<void> _copyPdfStyle(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    org,
  ) async {
    final effTheme = doc.pdfTheme ?? org.pdfTheme;
    final effPos = doc.logoPosition ?? org.logoPosition;
    final effTable = effectiveTableStyle(
      effTheme,
      doc.tableStyle ?? org.tableStyle,
    );

    final candidates = docProvider.allDocuments
        .where((d) => d.id != doc.id)
        .toList();

    final target = await showModalBottomSheet<QuoteflowDocument>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy PDF style to…',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pdfThemeLabel(effTheme)} · '
                      '${effPos == 'right' ? 'Right' : 'Left'} logo · '
                      '${tableStyleLabel(effTable)} table',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(child: Text('No other documents yet'))
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, i) {
                          final d = candidates[i];
                          final c = docProvider.getClientForDocument(
                            d.clientId,
                          );
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                              d.docNumber,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(c?.companyName ?? d.type.label),
                            onTap: () => Navigator.pop(ctx, d),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (target == null || !context.mounted) return;
    await docProvider.updateDocumentPdfStyle(
      target.id,
      pdfTheme: effTheme,
      logoPosition: effPos,
      tableStyle: effTable,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied PDF style to ${target.docNumber}')),
      );
    }
  }

  Widget _infoCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _dateCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _dateCardFull(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLineItemsTable(List<LineItem> items, String currency) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'UNIT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(items[i].description)),
                  Expanded(
                    child: Text(
                      items[i].quantity.toStringAsFixed(
                        items[i].quantity == items[i].quantity.roundToDouble()
                            ? 0
                            : 2,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatMoney(items[i].unitPrice, currency),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatMoney(rowTotal(items[i]), currency),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineItemsCards(List<LineItem> items, String currency) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${items[i].quantity.toStringAsFixed(items[i].quantity == items[i].quantity.roundToDouble() ? 0 : 2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Unit: ${formatMoney(items[i].unitPrice, currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatMoney(rowTotal(items[i]), currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _totalsCard(QuoteflowDocument doc, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', formatMoney(doc.subtotal, currency)),
          _totalRow(
            'Tax (${doc.taxRate.toStringAsFixed(doc.taxRate == doc.taxRate.roundToDouble() ? 0 : 1)}%)',
            formatMoney(doc.taxAmount, currency),
          ),
          if (doc.discount > 0)
            _totalRow('Discount', '− ${formatMoney(doc.discount, currency)}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Text(
                formatMoney(doc.total, currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _totalSummaryCard(QuoteflowDocument doc, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            doc.type.label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            doc.docNumber,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatMoney(doc.total, currency),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown to change document status
class _StatusDropdown extends StatelessWidget {
  final QuoteflowDocument doc;

  const _StatusDropdown({required this.doc});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.read<DocumentProvider>();
    // Reflect auto-overdue: an invoice past its due date reads as Overdue
    // here even when the stored status is still 'sent' or 'accepted'.
    final currentStatus = doc.effectiveStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<DocumentStatus>(
        value: currentStatus,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: DocumentStatus.values.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(status.label),
              ],
            ),
          );
        }).toList(),
        onChanged: (newStatus) {
          if (newStatus != null) {
            docProvider.updateDocumentStatus(doc.id, newStatus);
          }
        },
      ),
    );
  }

  Color _statusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.draft:
        return AppColors.gray;
      case DocumentStatus.sent:
        return AppColors.blue;
      case DocumentStatus.accepted:
        return AppColors.green;
      case DocumentStatus.paid:
        return AppColors.teal;
      case DocumentStatus.overdue:
        return AppColors.red;
      case DocumentStatus.declined:
        return AppColors.orange;
    }
  }
}
