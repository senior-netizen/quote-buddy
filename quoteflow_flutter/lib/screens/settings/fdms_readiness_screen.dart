import '../../utils/share_origin.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/zimra_provider.dart';
import '../../providers/organization_provider.dart';
import '../../services/compliance/fdms_readiness.dart';
import '../../services/storage.dart';
import '../../services/pdf_service.dart';
import '../../widgets/reference_design.dart';

class FdmsReadinessScreen extends StatefulWidget {
  const FdmsReadinessScreen({super.key});
  @override
  State<FdmsReadinessScreen> createState() => _FdmsReadinessScreenState();
}

class _FdmsReadinessScreenState extends State<FdmsReadinessScreen> {
  final _form = GlobalKey<FormState>();
  final _order = TextEditingController(),
      _branch = TextEditingController(),
      _supplier = TextEditingController(),
      _approval = TextEditingController();
  String? _region;
  bool _loaded = false, _busy = false;
  String? _error, _notice;
  @override
  void dispose() {
    for (final c in [_order, _branch, _supplier, _approval]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _export(FdmsReadiness evidence, {required bool draft}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final org = context.read<OrganizationProvider>().organization;
      if (org.tin != evidence.metadata['tin'])
        throw const FormatException(
          'Select the taxpayer business recorded in this evidence case.',
        );
      if (context.read<ZimraProvider>().evidenceError != null)
        throw const FormatException(
          'Resolve the evidence capture error before exporting.',
        );
      if (!draft && !evidence.ready)
        throw const FormatException(
          'Complete every recorded Test requirement before exporting for submission.',
        );
      final zimra = context.read<ZimraProvider>();
      if (!draft &&
          zimra.environment.name == 'test' &&
          (zimra.hasOfflineReceipts ||
              zimra.status.name != 'fiscalDayClosed')) {
        throw const FormatException(
          'Finish pending receipts and confirm the current Test fiscal day is closed before submission export.',
        );
      }
      final report = evidence.report();
      final files = <XFile>[], names = <String>[];
      final pdfManifest = <Map<String, String>>[];
      if (!draft) {
        final storage = context.read<StorageService>();
        final documents = storage.getAllDocuments();
        final exported = <int>{};
        for (final sample in evidence.samples) {
          final response = sample['response'] as Map,
              request = sample['request'] as Map;
          final id = int.parse(response['receiptID'].toString());
          if (!exported.add(id)) continue;
          final matches = documents
              .where(
                (d) =>
                    d.orgId == org.id &&
                    d.isFiscalised &&
                    d.fiscalDeviceId == evidence.identity['deviceId'] &&
                    d.fiscalReceiptId == id &&
                    d.fiscalQrPayload != null &&
                    evidenceDigest(d.fiscalRecord?['request']) ==
                        evidenceDigest(request),
              )
              .toList();
          if (matches.length != 1)
            throw FormatException(
              'Receipt $id needs its matching, unchanged fiscal document and QR code in this business before export.',
            );
          final document = matches.single;
          final pdf = await PdfService.generatePdf(
            doc: document,
            client: storage.getClient(document.clientId),
            org: org,
          );
          files.add(XFile.fromData(pdf, mimeType: 'application/pdf'));
          names.add('sample_receipt_$id.pdf');
          pdfManifest.add({
            'name': 'sample_receipt_$id.pdf',
            'sha256': evidenceFileDigest(pdf),
          });
        }
        report['samplePdfFiles'] = pdfManifest;
      }
      report.remove('sha256');
      report['sha256'] = evidenceDigest(report);
      final filename = draft
          ? 'quoteflow_fdms_DRAFT.json'
          : 'quoteflow_fdms_evidence.json';
      files.insert(
        0,
        XFile.fromData(
          Uint8List.fromList(
            utf8.encode(const JsonEncoder.withIndent('  ').convert(report)),
          ),
          mimeType: 'application/json',
        ),
      );
      names.insert(0, filename);
      if (!mounted) return;
      await Share.shareXFiles(
        files,
        sharePositionOrigin: shareOrigin(context),
        fileNameOverrides: names,
        text: draft
            ? 'Draft FDMS evidence - requirements may be incomplete.'
            : 'QuoteFlow FDMS Test evidence - manual ZIMRA review required.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zimra = context.watch<ZimraProvider>();
    final org = context.watch<OrganizationProvider>().organization;
    FdmsReadiness? evidence;
    String? loadError;
    try {
      evidence = zimra.approvalCase;
    } catch (e) {
      loadError = e.toString();
    }
    if (!_loaded && evidence != null) {
      final m = evidence.metadata;
      _order.text = '${m['orderNumber'] ?? ''}';
      _branch.text = '${m['branch'] ?? ''}';
      _supplier.text = '${m['supplier'] ?? ''}';
      _approval.text = '${m['approvalReference'] ?? ''}';
      _region = fdmsRegions.containsKey(m['region'])
          ? m['region'] as String
          : null;
      _loaded = true;
    }
    final checks = evidence?.checks ?? {};
    return Scaffold(
      appBar: referenceAppBar(
        context,
        'ZIMRA approval',
        subtitle: 'Readiness & evidence',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ReferenceNotice(
            'These are local readiness checks, not ZIMRA approval. Capture real Test submissions, then submit the evidence and Fiscal Device Order Number to your regional FDMS team.',
          ),
          if (loadError != null)
            Text(
              loadError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (evidence == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Register a Test device first. Evidence capture starts automatically for subsequent FDMS operations. Existing history is not fabricated or marked complete.',
              ),
            ),
          if (evidence != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Device ${evidence.identity['deviceId']} · ${evidence.identity['serialNumber']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Taxpayer: ${org.name} · TIN ${org.tin ?? 'not configured'}',
                      ),
                      for (final field in [
                        (_order, 'Fiscal Device Order Number'),
                        (_branch, 'TaRMS branch'),
                        (_supplier, 'Approved supplier'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: field.$1,
                            maxLength: 160,
                            decoration: InputDecoration(labelText: field.$2),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required for the approval request'
                                : null,
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _region,
                        hint: const Text('Select taxpayer region'),
                        validator: (value) => value == null
                            ? 'Select the taxpayer’s FDMS region'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Taxpayer region',
                        ),
                        items: fdmsRegions.keys
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _region = v),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        'Regional submission address: ${fdmsRegions[_region] ?? 'Select your taxpayer region'}',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _approval,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText:
                              'External ZIMRA approval reference (after review)',
                          helperText:
                              'Recording a reference does not verify it or issue approval.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (!_form.currentState!.validate()) return;
                                setState(() => _error = null);
                                try {
                                  await zimra.saveApprovalMetadata({
                                    'businessName': org.name,
                                    'tin': org.tin ?? '',
                                    'orderNumber': _order.text.trim(),
                                    'branch': _branch.text.trim(),
                                    'supplier': _supplier.text.trim(),
                                    'region': _region,
                                    'approvalReference': _approval.text.trim(),
                                  });
                                  if (mounted)
                                    setState(
                                      () => _notice =
                                          'Approval case details saved.',
                                    );
                                } catch (e) {
                                  if (mounted)
                                    setState(() => _error = e.toString());
                                }
                              },
                        child: const Text('Save approval case'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${checks.values.where((v) => v).length} of ${checks.length} requirements evidenced',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Only accepted receipts without validation errors from a confirmed closed Test day count. Tax coverage comes from FDMS configuration, not hard-coded rates.',
                    ),
                    const SizedBox(height: 12),
                    for (final check in checks.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              check.value
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: check.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(check.key)),
                          ],
                        ),
                      ),
                    const Text(
                      'Use the actual portal model/version. Demonstrate USD and ZWG (ZiG) using the same device; all applicable taxes, multiple Sale lines, buyer address/TIN, and original references on notes. Close the day, then Check Status until FDMS confirms it is closed. Scan every exported PDF QR and confirm its details match FDMS before sending.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${evidence.events.length} captured responses · ${evidence.samples.length} clean receipts in closed days',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _busy ||
                              !evidence.ready ||
                              zimra.evidenceError != null
                          ? null
                          : () => _export(evidence!, draft: false),
                      icon: const Icon(Icons.ios_share),
                      label: const Text(
                        'Export submission evidence + sample PDFs',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _export(evidence!, draft: true),
                      child: const Text(
                        'Export draft checklist and captured responses',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          for (final message in [zimra.evidenceError, _error, _notice])
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(message),
              ),
          const SizedBox(height: 16),
          const Text(
            'Portal sequence: taxpayer verifies branches in TaRMS → creates device order with an Approved Supplier → supplier completes the order → FDMS issues credentials. Activate within 24 hours. Server-to-Server live approval is manual; QuoteFlow account approval is separate. Report incidents promptly through regional FDMS support and the portal; the supplied guide specifies resolution within 8 hours.',
          ),
        ],
      ),
    );
  }
}
