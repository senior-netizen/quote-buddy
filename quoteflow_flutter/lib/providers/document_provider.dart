import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document.dart';
import '../models/client.dart';
import '../services/storage.dart';
import '../services/calculations.dart';
import '../services/tax_engine.dart';

class DocumentProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<QuoteflowDocument> _documents = [];
  DocumentType? _filter;
  DocumentStatus? _statusFilter;
  String _search = '';
  bool _showAll = false;

  DocumentProvider(this._storage) {
    refresh();
  }

  /// Documents visible in the current view: everything when [showAll] is
  /// on, otherwise only the active organization's documents.
  List<QuoteflowDocument> get _scoped => _showAll
      ? _documents
      : _documents.where((d) => d.orgId == _storage.getActiveOrg().id).toList();

  /// When true, stats and lists include every organization's documents.
  bool get showAll => _showAll;

  void setShowAll(bool value) {
    _showAll = value;
    notifyListeners();
  }

  List<QuoteflowDocument> get documents {
    var docs = _scoped;

    // Type filter
    if (_filter != null) {
      docs = docs
          .where((d) => d.docType == documentTypeToString(_filter!))
          .toList();
    }

    // Status filter — compares against the effective status so past-due
    // invoices show up under the Overdue filter without manual marking.
    if (_statusFilter != null) {
      docs = docs.where((d) => d.effectiveStatus == _statusFilter).toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      docs = docs.where((d) {
        final client = _storage.getClient(d.clientId);
        return d.docNumber.toLowerCase().contains(q) ||
            (client?.companyName.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return docs;
  }

  List<QuoteflowDocument> get allDocuments => _documents;

  DocumentType? get filter => _filter;
  DocumentStatus? get statusFilter => _statusFilter;
  String get search => _search;

  int get quotesCount => _scoped.where((d) => d.docType == 'quote').length;
  int get invoicesCount => _scoped.where((d) => d.docType == 'invoice').length;
  double get quoteValue => _scoped
      .where((d) => d.docType == 'quote')
      .fold<double>(0, (s, d) => s + d.total);
  double get invoiceValue => _scoped
      .where((d) => d.docType == 'invoice')
      .fold<double>(0, (s, d) => s + d.total);

  /// Value billed on invoices that has not been paid yet
  /// (statuses: sent, accepted, overdue).
  double get outstandingValue {
    const pending = {'sent', 'accepted', 'overdue'};
    return _scoped
        .where((d) => d.docType == 'invoice' && pending.contains(d.docStatus))
        .fold<double>(0, (s, d) => s + d.total);
  }

  /// Money actually received: paid invoices plus receipts.
  double get paidValue {
    return _scoped
        .where(
          (d) =>
              (d.docType == 'invoice' && d.docStatus == 'paid') ||
              d.docType == 'receipt',
        )
        .fold<double>(0, (s, d) => s + d.total);
  }

  /// Documents grouped by month for chart data
  Map<String, double> get monthlyRevenue {
    final now = DateTime.now();
    final Map<String, double> revenue = {};

    // Initialize last 6 months
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      revenue[key] = 0;
    }

    for (final doc in _scoped) {
      if (doc.docType != 'invoice' && doc.docType != 'receipt') continue;
      // Count only money actually received: paid invoices and receipts.
      final received = doc.docType == 'receipt'
          ? doc.docStatus != 'declined'
          : doc.docStatus == 'paid';
      if (!received) continue;
      try {
        final date = DateTime.parse(doc.issueDate);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (revenue.containsKey(key)) {
          revenue[key] = revenue[key]! + doc.total;
        }
      } catch (_) {}
    }

    return revenue;
  }

  /// Quote-to-invoice conversion rate.
  ///
  /// Numerator: distinct quotes that were converted into invoices.
  /// Denominator: quotes that moved past draft (sent / accepted /
  /// overdue) plus any quote that was converted, so a fresh draft
  /// never drags the rate down and duplicate invoices can't push it
  /// over 100%.
  double get conversionRate {
    final convertedQuoteIds = _scoped
        .where((d) => d.convertedFrom != null)
        .map((d) => d.convertedFrom!)
        .toSet();
    if (convertedQuoteIds.isEmpty) return 0;

    final progressed = _scoped.where((d) {
      if (d.docType != 'quote') return false;
      if (convertedQuoteIds.contains(d.id)) return true;
      const progressedStatuses = {'sent', 'accepted', 'overdue'};
      return progressedStatuses.contains(d.docStatus);
    }).length;
    if (progressed == 0) return 0;

    final converted = convertedQuoteIds
        .where((id) => _scoped.any((d) => d.id == id))
        .length;
    return (converted / progressed).clamp(0.0, 1.0);
  }

  List<QuoteflowDocument> recentDocuments([int limit = 8]) {
    return _scoped.take(limit).toList();
  }

  /// Invoices that are currently past due (derived from their due date or
  /// manually marked), sorted oldest first so the most urgent lead the list.
  List<QuoteflowDocument> get overdueDocuments {
    final docs =
        _scoped
            .where(
              (d) =>
                  d.docType == 'invoice' &&
                  d.effectiveStatus == DocumentStatus.overdue,
            )
            .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a.dueDate ?? '');
            final db = DateTime.tryParse(b.dueDate ?? '');
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
    return docs;
  }

  /// Get all documents for a specific client
  List<QuoteflowDocument> getDocumentsForClient(String clientId) {
    return _scoped.where((d) => d.clientId == clientId).toList();
  }

  QuoteflowDocument? getDocument(String id) => _storage.getDocument(id);

  Client? getClientForDocument(String clientId) => _storage.getClient(clientId);

  void setFilter(DocumentType? type) {
    _filter = type;
    notifyListeners();
  }

  void setStatusFilter(DocumentStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  String nextDocNumber(DocumentType type) {
    final year = DateTime.now().year.toString();
    final prefix = type.prefix;
    final like = '$prefix-$year-';

    final existing = _scoped.where((d) => d.docNumber.startsWith(like)).map((
      d,
    ) {
      final parts = d.docNumber.split('-');
      return int.tryParse(parts.last) ?? 0;
    }).toList()..sort();

    final next = existing.isEmpty ? 1 : existing.last + 1;
    return '$prefix-$year-${next.toString().padLeft(4, '0')}';
  }

  Future<QuoteflowDocument> createDocument({
    required DocumentType type,
    required String docNumber,
    required String issueDate,
    String? dueDate,
    required String clientId,
    required List<LineItem> lineItems,
    required double taxRate,
    required double discount,
    String? notes,
    String? convertedFrom,
    String status = 'draft',
    bool includeBuyerDetails = false,
  }) => createDocumentV2(
    type: type,
    docNumber: docNumber,
    issueDate: issueDate,
    dueDate: dueDate,
    clientId: clientId,
    lineItems: lineItems,
    taxRate: taxRate,
    discount: discount,
    notes: notes,
    convertedFrom: convertedFrom,
    status: status,
    includeBuyerDetails: includeBuyerDetails,
  );

  /// Treatment-aware document creation. Totals come from the tax engine
  /// using the organisation's tax profile; [taxRate] (optional) is only a
  /// legacy-compat hint — the per-line treatments win.
  Future<QuoteflowDocument> createDocumentV2({
    required DocumentType type,
    required String docNumber,
    required String issueDate,
    String? dueDate,
    required String clientId,
    required List<LineItem> lineItems,
    double? taxRate,
    required double discount,
    String? notes,
    String? convertedFrom,
    String status = 'draft',
    bool includeBuyerDetails = false,
  }) async {
    final org = _storage.getActiveOrg();
    final totals = computeTotalsV2(
      items: lineItems,
      org: org,
      discount: discount,
    );

    final doc = QuoteflowDocument(
      id: _uuid.v4(),
      docType: documentTypeToString(type),
      docNumber: docNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      lineItems: lineItems,
      taxRate: totals.effectiveRate,
      discount: discount,
      subtotal: totals.subtotal,
      taxAmount: totals.taxAmount,
      total: totals.total,
      notes: notes,
      clientId: clientId,
      createdAt: DateTime.now().toIso8601String(),
      convertedFrom: convertedFrom,
      docStatus: status,
      orgId: org.id,
      includeBuyerDetails: includeBuyerDetails,
    );

    await _storage.saveDocument(doc);
    refresh();
    return doc;
  }

  /// Persist fiscalisation fields that were set directly on the document
  /// (see services/fiscalisation.dart). Totals are never recomputed here.
  Future<void> saveFiscalisation(QuoteflowDocument doc) async {
    await _storage.saveDocument(doc);
    refresh();
  }

  Future<void> updateDocument(QuoteflowDocument doc) async {
    final stored = _storage.getDocument(doc.id);
    if (stored?.isFiscalised == true || stored?.isFiscalPending == true) {
      throw StateError('Fiscalised or pending documents cannot be edited.');
    }
    final activeOrg = _storage.getActiveOrg();
    final ownerId = doc.orgId ?? activeOrg.id;
    final owners = _storage.listOrgs().where((org) => org.id == ownerId);
    if (owners.isEmpty)
      throw StateError('The document owner no longer exists.');
    final org = owners.single;
    final previous = _storage.getDocument(doc.id);
    final changed =
        previous == null ||
        previous.discount != doc.discount ||
        jsonEncode(previous.lineItems.map((line) => line.toJson()).toList()) !=
            jsonEncode(doc.lineItems.map((line) => line.toJson()).toList());
    final hasTreatments = doc.lineItems.any((l) => l.taxTreatment != null);
    // Preserve untouched historical legacy totals. Financial edits must still
    // recalculate, and always use the document owner's tax configuration.
    if (!hasTreatments && !org.taxEnabled && doc.taxRate > 0 && changed) {
      final totals = computeTotals(doc.lineItems, doc.taxRate, doc.discount);
      doc
        ..subtotal = totals.subtotal
        ..taxAmount = totals.taxAmount
        ..total = totals.total;
    } else if (changed || hasTreatments || org.taxEnabled || doc.taxRate == 0) {
      final totals = computeTotalsV2(
        items: doc.lineItems,
        org: org,
        discount: doc.discount,
      );
      doc
        ..taxRate = totals.effectiveRate
        ..subtotal = totals.subtotal
        ..taxAmount = totals.taxAmount
        ..total = totals.total;
    }

    await _storage.saveDocument(doc);
    refresh();
  }

  /// Attach (or clear, when null) the hand-drawn signature for a document.
  /// Recording the signature stamps a signedAt timestamp; clearing it
  /// removes both.
  Future<void> updateDocumentSignature(
    String docId,
    String? signatureData,
  ) async {
    final doc = _storage.getDocument(docId);
    if (doc != null) {
      doc.signatureData = signatureData;
      doc.signedAt = signatureData != null
          ? DateTime.now().toIso8601String()
          : null;
      await _storage.saveDocument(doc);
      refresh();
    }
  }

  /// Set per-document PDF style fields. A null value means "use the
  /// organization's default" for that field; any value overrides it.
  /// All three fields are set explicitly on every call.
  Future<void> updateDocumentPdfStyle(
    String docId, {
    String? pdfTheme,
    String? logoPosition,
    String? tableStyle,
  }) async {
    final doc = _storage.getDocument(docId);
    if (doc != null) {
      doc.pdfTheme = pdfTheme;
      doc.logoPosition = logoPosition;
      doc.tableStyle = tableStyle;
      await _storage.saveDocument(doc);
      refresh();
    }
  }

  /// Remove every per-document PDF override so the document follows the
  /// organization's global PDF settings again.
  Future<void> clearDocumentPdfOverrides(String docId) async {
    final doc = _storage.getDocument(docId);
    if (doc != null) {
      doc.pdfTheme = null;
      doc.logoPosition = null;
      doc.tableStyle = null;
      await _storage.saveDocument(doc);
      refresh();
    }
  }

  Future<void> updateDocumentStatus(
    String docId,
    DocumentStatus newStatus,
  ) async {
    final doc = _storage.getDocument(docId);
    if (doc != null) {
      doc.docStatus = documentStatusToString(newStatus);
      await _storage.saveDocument(doc);
      refresh();
    }
  }

  Future<void> deleteDocument(String id) async {
    await _storage.deleteDocument(id);
    refresh();
  }

  /// Duplicate a document with a new number
  Future<QuoteflowDocument> duplicateDocument(
    QuoteflowDocument original,
  ) async {
    final newNumber = nextDocNumber(original.type);

    return createDocument(
      type: original.type,
      includeBuyerDetails: original.includeBuyerDetails,
      docNumber: newNumber,
      issueDate: todayISO(),
      dueDate: original.dueDate,
      clientId: original.clientId,
      lineItems: original.lineItems
          .map(
            (li) => LineItem(
              description: li.description,
              quantity: li.quantity,
              unitPrice: li.unitPrice,
            ),
          )
          .toList(),
      taxRate: original.taxRate,
      discount: original.discount,
      notes: original.notes,
      status: 'draft',
    );
  }

  Future<QuoteflowDocument> convertToInvoice(QuoteflowDocument quote) async {
    final newNumber = nextDocNumber(DocumentType.invoice);

    return createDocument(
      type: DocumentType.invoice,
      includeBuyerDetails: quote.includeBuyerDetails,
      docNumber: newNumber,
      issueDate: todayISO(),
      dueDate: quote.dueDate,
      clientId: quote.clientId,
      lineItems: quote.lineItems
          .map(
            (li) => LineItem(
              description: li.description,
              quantity: li.quantity,
              unitPrice: li.unitPrice,
            ),
          )
          .toList(),
      taxRate: quote.taxRate,
      discount: quote.discount,
      notes: quote.notes,
      convertedFrom: quote.id,
    );
  }

  void refresh() {
    _documents = _storage.getAllDocuments();
    notifyListeners();
  }
}
