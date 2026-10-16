import 'dart:convert';
import 'customer_form.dart';
import 'reference_design.dart';
import 'customer_fiscal_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../screens/products_screen.dart';
import '../models/organization.dart';
import '../providers/document_provider.dart';
import '../providers/client_provider.dart';
import '../providers/organization_provider.dart';
import '../services/calculations.dart';
import '../services/pdf_service.dart';
import '../services/tax_engine.dart';
import '../theme/app_theme.dart';

class DocumentFormScreen extends StatefulWidget {
  final QuoteflowDocument? editDoc;

  const DocumentFormScreen({super.key, this.editDoc});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  late DocumentType _docType;
  late DocumentStatus _docStatus;
  late TextEditingController _docNumberCtrl;
  late TextEditingController _issueDateCtrl;
  late TextEditingController _dueDateCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _notesCtrl;

  /// Per-line tax treatment ('no_tax' | 'standard' | 'zero_rated' |
  /// 'exempt'). Null entries fall back to the organisation default.
  /// Kept parallel to [_items]; an empty list means "all default".
  List<String?> _lineTreatments = [];
  String? _clientId;
  bool _includeBuyerDetails = false;
  List<LineItem> _items = [];
  bool _loaded = false;
  bool _dueDateDefaulted = false;
  bool _saving = false;
  bool _allowPop = false;
  String? _initialSnapshot;
  String _snapshot() => jsonEncode([
    _docType.name,
    _docStatus.name,
    _clientId,
    _includeBuyerDetails,
    _docNumberCtrl.text,
    _issueDateCtrl.text,
    _dueDateCtrl.text,
    _discountCtrl.text,
    _notesCtrl.text,
    _items.map((item) => item.toJson()).toList(),
    _lineTreatments,
  ]);

  void _refreshDirty() {
    if (mounted && _initialSnapshot != null) setState(() {});
  }

  Future<void> _confirmLeave() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text('Your changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _itemCtrls.removeAt(index).dispose();
      if (index < _lineTreatments.length) _lineTreatments.removeAt(index);
    });
  }

  DateTime? _parseDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
      return null;
    return date.toIso8601String().substring(0, 10) == value ? date : null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    var initial = _parseDate(controller.text) ?? DateTime.now();
    if (initial.isBefore(DateTime(2000)) ||
        initial.isAfter(DateTime(2100, 12, 31))) {
      initial = DateTime.now();
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted)
      controller.text = date.toIso8601String().substring(0, 10);
  }

  /// Persisted controllers for line-item fields so they aren't
  /// recreated on every build (which causes keyboard dismiss + cursor reset).
  final List<_LineItemControllers> _itemCtrls = [];

  @override
  void initState() {
    super.initState();
    _docType = widget.editDoc?.type ?? DocumentType.quote;
    _docStatus = widget.editDoc?.status ?? DocumentStatus.draft;
    _docNumberCtrl = TextEditingController();
    _issueDateCtrl = TextEditingController(text: todayISO());
    // Populated from the organisation's payment terms on first build.
    _dueDateCtrl = TextEditingController();
    _discountCtrl = TextEditingController(text: '0');
    _notesCtrl = TextEditingController();
    for (final controller in [
      _docNumberCtrl,
      _issueDateCtrl,
      _dueDateCtrl,
      _discountCtrl,
      _notesCtrl,
    ]) {
      controller.addListener(_refreshDirty);
    }
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _issueDateCtrl.dispose();
    _dueDateCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromDoc(QuoteflowDocument doc, DocumentProvider dp) {
    if (_loaded) return;
    _docType = doc.type;
    _docStatus = doc.status;
    _docNumberCtrl.text = doc.docNumber;
    _issueDateCtrl.text = doc.issueDate;
    _dueDateCtrl.text = doc.dueDate ?? '';
    _discountCtrl.text = doc.discount.toString();
    _notesCtrl.text = doc.notes ?? '';
    _clientId = doc.clientId;
    _includeBuyerDetails = doc.includeBuyerDetails;
    _items = doc.lineItems
        .map(
          (li) => LineItem(
            description: li.description,
            quantity: li.quantity,
            unitPrice: li.unitPrice,
            taxTreatment: li.taxTreatment,
          ),
        )
        .toList();
    _lineTreatments = _items.map((li) => li.taxTreatment).toList();
    _syncItemControllers();
    _loaded = true;
  }

  /// Keep the controller list in sync with the _items list.
  void _syncItemControllers() {
    // Add controllers for any new items
    while (_itemCtrls.length < _items.length) {
      final idx = _itemCtrls.length;
      _itemCtrls.add(
        _LineItemControllers(
          description: TextEditingController(text: _items[idx].description),
          quantity: TextEditingController(
            text: _qtyDisplay(_items[idx].quantity),
          ),
          unitPrice: TextEditingController(
            text: _priceDisplay(_items[idx].unitPrice),
          ),
        ),
      );
    }
    // Remove extras
    while (_itemCtrls.length > _items.length) {
      _itemCtrls.removeLast().dispose();
    }
  }

  String _qtyDisplay(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  String _priceDisplay(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final clientProvider = context.watch<ClientProvider>();
    final orgProvider = context.watch<OrganizationProvider>();
    final ownerId = widget.editDoc?.orgId;
    final org = ownerId == null
        ? orgProvider.organization
        : orgProvider.organizations.firstWhere(
            (org) => org.id == ownerId,
            orElse: () => orgProvider.organization,
          );
    final isEditing = widget.editDoc != null;

    if (isEditing && !_loaded) {
      final doc = docProvider.getDocument(widget.editDoc!.id);
      if (doc != null) _initFromDoc(doc, docProvider);
    }

    // Generate doc number on first load
    if (_docNumberCtrl.text.isEmpty && !_loaded) {
      _docNumberCtrl.text = docProvider.nextDocNumber(_docType);
    }

    // Per-line treatment defaults come from the organisation tax profile.
    if (_lineTreatments.length < _items.length) {
      _lineTreatments = List<String?>.from(_items.map((_) => null));
    }

    // Sync default due date from the organisation's payment terms
    // (e.g. net 14). Applied once, before the user has typed anything.
    if (!_loaded && !_dueDateDefaulted) {
      _dueDateDefaulted = true;
      final terms = org.defaultPaymentTerms ?? 14;
      if (terms > 0) {
        _dueDateCtrl.text = plusDaysISO(terms);
      }
    }

    if (_items.isEmpty) {
      _items = [LineItem(description: '', quantity: 1, unitPrice: 0)];
    }

    // Ensure controllers match items
    _syncItemControllers();

    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final totals = computeTotalsV2(items: _items, org: org, discount: discount);
    final currency = org.currency;
    final client = _clientId != null
        ? clientProvider
              .clientsForOrganization(widget.editDoc?.orgId ?? org.id)
              .firstWhere(
                (c) => c.id == _clientId,
                orElse: () => Client(id: '', companyName: '—'),
              )
        : null;

    while (_lineTreatments.length < _items.length) {
      _lineTreatments.add(null);
    }
    _initialSnapshot ??= _snapshot();
    return PopScope(
      canPop: !_saving && (_allowPop || _snapshot() == _initialSnapshot),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: referenceAppBar(
          context,
          isEditing
              ? 'Edit ${_docType.label.toLowerCase()}'
              : 'New ${_docType.label.toLowerCase()}',
          subtitle: 'DOCUMENT DETAILS',
          actions: [
            TextButton.icon(
              onPressed: () =>
                  _save(context, docProvider, clientProvider, org, totals),
              icon: const Icon(Icons.check, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: _buildForm(
                      context,
                      docProvider,
                      clientProvider,
                      org,
                    ),
                  ),
                  _buildSidebar(
                    totals,
                    currency,
                    client,
                    context,
                    org,
                    docProvider,
                    clientProvider,
                    isEditing,
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  Expanded(
                    child: _buildForm(
                      context,
                      docProvider,
                      clientProvider,
                      org,
                    ),
                  ),
                  _buildCompactSummary(
                    totals,
                    currency,
                    client,
                    context,
                    org,
                    docProvider,
                    clientProvider,
                    isEditing,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    DocumentProvider docProvider,
    ClientProvider clientProvider,
    org,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doc type selector
          _sectionLabel('DOCUMENT TYPE'),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 20),

          // Doc number + dates + status
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    _field('DOCUMENT NUMBER', _docNumberCtrl),
                    const SizedBox(height: 12),
                    _field('ISSUE DATE', _issueDateCtrl),
                    const SizedBox(height: 12),
                    _field(
                      _docType == DocumentType.invoice ||
                              _docType == DocumentType.creditNote
                          ? 'DUE DATE'
                          : 'VALID UNTIL',
                      _dueDateCtrl,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusSelector(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field('DOCUMENT NUMBER', _docNumberCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _field('ISSUE DATE', _issueDateCtrl)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _docType == DocumentType.invoice ||
                              _docType == DocumentType.creditNote
                          ? 'DUE DATE'
                          : 'VALID UNTIL',
                      _dueDateCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusSelector()),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Client selector
          _sectionLabel('CLIENT'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _clientId,
                  decoration: InputDecoration(
                    hintText: 'Select a client',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: clientProvider
                      .clientsForOrganization(widget.editDoc?.orgId ?? org.id)
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.companyName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _clientId = v;
                    _includeBuyerDetails =
                        clientProvider.getClient(v ?? '')?.useFiscalDetails ??
                        false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => _addClient(context),
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add client',
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_clientId != null && _docType.isFiscal)
            CustomerFiscalDetails(
              customer: clientProvider.getClient(_clientId!),
              include: _includeBuyerDetails,
              onChanged: (v) => setState(() => _includeBuyerDetails = v),
              onEdited: () {
                if (mounted) setState(() {});
              },
            ),

          // Line items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _sectionLabel('LINE ITEMS')),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _items.add(
                      LineItem(description: '', quantity: 1, unitPrice: 0),
                    );
                    while (_lineTreatments.length < _items.length) {
                      _lineTreatments.add(null);
                    }
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add row'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLineItemsEditor(org.currency, org),
          if (context.read<ProductProvider?>() != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Add from inventory'),
                onPressed: () async {
                  final product = await Navigator.push<Product>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductsScreen(
                        picking: true,
                        orgId: widget.editDoc?.orgId ?? org.id,
                      ),
                    ),
                  );
                  if (product == null || !mounted) return;
                  setState(() {
                    final line = LineItem(
                      description: product.name,
                      quantity: 1,
                      unitPrice: product.price,
                    );
                    if (_items.length == 1 &&
                        _items.first.description.trim().isEmpty &&
                        _items.first.unitPrice == 0) {
                      _items[0] = line;
                      _syncItemControllers();
                      _itemCtrls[0].description.text = line.description;
                      _itemCtrls[0].quantity.text = '1';
                      _itemCtrls[0].unitPrice.text = _priceDisplay(
                        line.unitPrice,
                      );
                    } else {
                      _items.add(line);
                      _lineTreatments.add(null);
                      _syncItemControllers();
                    }
                  });
                },
              ),
            ),
          const SizedBox(height: 20),

          // Tax + discount. Tax controls follow the ORGANISATION tax
          // profile: a tax-disabled business never sees a VAT field here.
          if (org.taxEnabled) ...[
            Row(
              children: [
                Expanded(child: _buildDefaultTreatmentSelector(org)),
                const SizedBox(width: 12),
                Expanded(child: _numberField('DISCOUNT', _discountCtrl)),
              ],
            ),
            if (_hasMixedTreatments(org)) ...[
              const SizedBox(height: 8),
              Text(
                'Individual lines override the default treatment below.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'No tax — this organisation is not registered for tax.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(child: _numberField('DISCOUNT', _discountCtrl)),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Notes
          _sectionLabel('NOTES (OPTIONAL)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Payment terms, delivery details, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    DocumentTotals totals,
    String currency,
    Client? client,
    BuildContext context,
    org,
    DocumentProvider docProvider,
    ClientProvider clientProvider,
    bool isEditing,
  ) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('SUMMARY'),
          const SizedBox(height: 16),
          _summaryRow('Subtotal', formatMoney(totals.subtotal, currency)),
          // Tax row only appears when tax actually applies — a non-VAT
          // business never sees a fabricated "Tax (15.5%)" line.
          if (totals.taxAmount > 0)
            _summaryRow(
              _taxSummaryLabel(totals),
              formatMoney(totals.taxAmount, currency),
            ),
          if ((double.tryParse(_discountCtrl.text) ?? 0) > 0)
            _summaryRow(
              'Discount',
              '− ${formatMoney(double.tryParse(_discountCtrl.text) ?? 0, currency)}',
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                formatMoney(totals.total, currency),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _previewPdf(context, org),
              child: const Text('Preview PDF'),
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  _save(context, docProvider, clientProvider, org, totals),
              child: Text(isEditing ? 'Save changes' : 'Save & download'),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Document ${_docNumberCtrl.text.isEmpty ? "—" : _docNumberCtrl.text} · ${client?.companyName ?? "No client selected"}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(
    DocumentTotals totals,
    String currency,
    Client? client,
    BuildContext context,
    org,
    DocumentProvider docProvider,
    ClientProvider clientProvider,
    bool isEditing,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final total = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatMoney(totals.total, currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.primary,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => _previewPdf(context, org),
                  child: const Text('Preview'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () => _save(
                          context,
                          docProvider,
                          clientProvider,
                          org,
                          totals,
                        ),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            );
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [total, const SizedBox(height: 8), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: total),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: DocumentType.values.map((type) {
        final selected = _docType == type;
        return GestureDetector(
          onTap: () {
            setState(() {
              _docType = type;
              final dp = context.read<DocumentProvider>();
              if (widget.editDoc == null) {
                _docNumberCtrl.text = dp.nextDocNumber(type);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: selected
                  ? null
                  : Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
            ),
            child: Text(
              type.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Document-level default treatment selector (tax-enabled orgs only).
  Widget _buildDefaultTreatmentSelector(Organization org) {
    final defs = org.taxDefinitions.where((t) => t.enabled).toList();
    final current = _docDefaultTreatment(org);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TAX TREATMENT'),
        const SizedBox(height: 6),
        DropdownButtonFormField<TaxTreatment>(
          value: current,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          items: [
            for (final t in TaxTreatment.values)
              if (t == TaxTreatment.noTax || defs.any((d) => d.type == t))
                DropdownMenuItem(
                  value: t,
                  child: Text(_treatmentLabel(org, t)),
                ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              // Set the default: clear per-line overrides that match it.
              _lineTreatments = List.generate(
                _items.length,
                (i) => _lineTreatments[i] == taxTreatmentToString(v)
                    ? null
                    : _lineTreatments[i],
              );
            });
          },
        ),
      ],
    );
  }

  /// Summary label for the tax row: names the treatment(s) actually on the
  /// document, never a hard-coded rate.
  String _taxSummaryLabel(DocumentTotals totals) {
    final rates = totals.lines.map((l) => l.rate).whereType<double>().toSet();
    if (rates.length == 1) {
      final r = rates.first;
      return r == r.roundToDouble()
          ? 'Tax (${r.toStringAsFixed(0)}%)'
          : 'Tax (${r.toStringAsFixed(1)}%)';
    }
    return 'Tax';
  }

  /// The document default: first line's treatment if all agree, else the
  /// organisation default. Purely presentational for the selector.
  TaxTreatment _docDefaultTreatment(Organization org) {
    final treatments = _lineTreatments
        .take(_items.length)
        .map((t) => t == null ? null : taxTreatmentFromString(t))
        .toList();
    final distinct = treatments.whereType<TaxTreatment>().toSet();
    if (distinct.length == 1) return distinct.first;
    if (distinct.isEmpty) return defaultTaxTreatment(org);
    return defaultTaxTreatment(org);
  }

  bool _hasMixedTreatments(Organization org) {
    final distinct = _lineTreatments
        .take(_items.length)
        .whereType<String>()
        .toSet();
    return distinct.length > 1;
  }

  String _treatmentLabel(Organization org, TaxTreatment t) {
    final def = org.taxDefinitions.where((d) => d.type == t).firstOrNull;
    final rate = def?.rate;
    final base = t.label;
    if (rate == null) return base;
    return rate == rate.roundToDouble()
        ? '$base (${rate.toStringAsFixed(0)}%)'
        : '$base (${rate.toStringAsFixed(1)}%)';
  }

  /// Per-line treatment dropdown shown in each line row (tax-enabled orgs).
  Widget _lineTreatmentPicker(int i, Organization org, {bool compact = false}) {
    final defs = org.taxDefinitions.where((t) => t.enabled).toList();
    final current = _lineTreatments.length > i && _lineTreatments[i] != null
        ? taxTreatmentFromString(_lineTreatments[i])
        : null;
    return DropdownButtonFormField<TaxTreatment>(
      value: current,
      isExpanded: true,
      hint: Text(
        _treatmentLabel(org, defaultTaxTreatment(org)),
        style: const TextStyle(fontSize: 12.5),
      ),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      items: [
        for (final t in TaxTreatment.values)
          if (t == TaxTreatment.noTax || defs.any((d) => d.type == t))
            DropdownMenuItem(
              value: t,
              child: Text(
                _treatmentLabel(org, t),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
      ],
      onChanged: (v) {
        setState(() {
          while (_lineTreatments.length < _items.length) {
            _lineTreatments.add(null);
          }
          _lineTreatments[i] = v == null ? null : taxTreatmentToString(v);
        });
      },
    );
  }

  Widget _buildLineItemsEditor(String currency, Organization org) {
    return Column(
      children: [
        for (int i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLineItemRow(i, currency, org),
          ),
      ],
    );
  }

  Widget _buildLineItemRow(int i, String currency, Organization org) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ctrl = _itemCtrls[i];

        if (constraints.maxWidth < 500) {
          // ── Stacked layout for narrow screens ──
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl.description,
                        decoration: InputDecoration(
                          hintText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          _items[i].description = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _items.length > 1
                          ? () => _removeItem(i)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (org.taxEnabled) ...[
                  const SizedBox(height: 8),
                  _lineTreatmentPicker(i, org, compact: true),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl.quantity,
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        onChanged: (v) {
                          _items[i].quantity = double.tryParse(v) ?? 0;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ctrl.unitPrice,
                        decoration: const InputDecoration(
                          hintText: 'Unit price',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        onChanged: (v) {
                          _items[i].unitPrice = double.tryParse(v) ?? 0;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(rowTotal(_items[i]), currency),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // ── Wide layout — single row ──
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: ctrl.description,
                    decoration: InputDecoration(
                      hintText: 'Item or service description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _items[i].description = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl.quantity,
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (v) {
                      _items[i].quantity = double.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl.unitPrice,
                    decoration: const InputDecoration(
                      hintText: 'Unit price',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    onChanged: (v) {
                      _items[i].unitPrice = double.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Text(
                    formatMoney(rowTotal(_items[i]), currency),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _items.length > 1 ? () => _removeItem(i) : null,
                ),
              ],
            ),
            if (org.taxEnabled) ...[
              const SizedBox(height: 6),
              SizedBox(width: 220, child: _lineTreatmentPicker(i, org)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STATUS'),
        const SizedBox(height: 6),
        DropdownButtonFormField<DocumentStatus>(
          isExpanded: true,
          value: _docStatus,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
                  Flexible(
                    child: Text(status.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _docStatus = v);
          },
        ),
      ],
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

  Widget _sectionLabel(String text) {
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

  Widget _field(String label, TextEditingController ctrl) {
    final isDate = ctrl == _issueDateCtrl || ctrl == _dueDateCtrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: isDate,
          onTap: isDate ? () => _pickDate(ctrl) : null,
          decoration: InputDecoration(
            hintText: isDate ? 'YYYY-MM-DD' : null,
            suffixIcon: isDate
                ? IconButton(
                    tooltip: 'Choose date',
                    onPressed: () => _pickDate(ctrl),
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
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

  Future<void> _addClient(BuildContext context) async {
    final client = await showCustomerForm(context);
    if (client != null && mounted)
      setState(() {
        _clientId = client.id;
        _includeBuyerDetails = client.useFiscalDetails;
      });
  }

  String? _validate() {
    if (_clientId == null) return 'Select a client';
    if (_docNumberCtrl.text.trim().isEmpty) return 'Document number missing';
    if (_parseDate(_issueDateCtrl.text.trim()) == null)
      return 'Choose a valid issue date';
    final due = _dueDateCtrl.text.trim();
    if (due.isNotEmpty && _parseDate(due) == null)
      return 'Choose a valid due or expiry date';
    if (due.isNotEmpty &&
        _parseDate(due)!.isBefore(_parseDate(_issueDateCtrl.text.trim())!))
      return 'Due or expiry date cannot be before the issue date';
    if (_items.isEmpty) return 'Add at least one line item';
    if (_items.any((i) => !i.quantity.isFinite || i.quantity <= 0))
      return 'Each quantity must be greater than zero';
    if (_items.any((i) => !i.unitPrice.isFinite || i.unitPrice < 0))
      return 'Unit prices must be zero or greater';
    final discount = double.tryParse(_discountCtrl.text);
    if (discount == null || !discount.isFinite || discount < 0)
      return 'Enter a valid discount';
    final subtotal = _items.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.unitPrice,
    );
    if (discount > subtotal) return 'Discount cannot exceed the subtotal';
    if (_items.any((i) => i.description.trim().isEmpty)) {
      return 'All line items need a description';
    }
    return null;
  }

  Future<void> _save(
    BuildContext context,
    DocumentProvider docProvider,
    ClientProvider clientProvider,
    org,
    DocumentTotals totals,
  ) async {
    if (_saving) return;
    final savedDocument = widget.editDoc == null
        ? null
        : docProvider.getDocument(widget.editDoc!.id);
    if (savedDocument?.isFiscalised == true ||
        savedDocument?.isFiscalPending == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This fiscal document is locked. Resolve any pending submission or create a credit/debit note for a correction.',
          ),
        ),
      );
      return;
    }
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final discount = double.tryParse(_discountCtrl.text) ?? 0;

    setState(() => _saving = true);
    try {
      // Effective per-line treatments (org default fills unassigned lines).
      while (_lineTreatments.length < _items.length) {
        _lineTreatments.add(null);
      }

      if (widget.editDoc != null) {
        final existing = docProvider.getDocument(widget.editDoc!.id);
        if (existing == null) throw StateError('Document no longer exists');
        final doc = QuoteflowDocument.fromJson(existing.toJson());
        {
          doc
            ..docType = documentTypeToString(_docType)
            ..docNumber = _docNumberCtrl.text.trim()
            ..issueDate = _issueDateCtrl.text.trim()
            ..dueDate = _dueDateCtrl.text.trim().isEmpty
                ? null
                : _dueDateCtrl.text.trim()
            ..includeBuyerDetails = _includeBuyerDetails
            ..clientId = _clientId!
            ..lineItems = _items
                .asMap()
                .entries
                .map(
                  (e) => LineItem(
                    description: e.value.description,
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    taxTreatment: _lineTreatments[e.key],
                  ),
                )
                .toList()
            ..discount = discount
            ..notes = _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim()
            ..docStatus = documentStatusToString(_docStatus);
          await docProvider.updateDocument(doc);
        }
      } else {
        await docProvider.createDocumentV2(
          type: _docType,
          includeBuyerDetails: _includeBuyerDetails,
          docNumber: _docNumberCtrl.text.trim(),
          issueDate: _issueDateCtrl.text.trim(),
          dueDate: _dueDateCtrl.text.trim().isEmpty
              ? null
              : _dueDateCtrl.text.trim(),
          clientId: _clientId!,
          lineItems: _items
              .asMap()
              .entries
              .map(
                (e) => LineItem(
                  description: e.value.description,
                  quantity: e.value.quantity,
                  unitPrice: e.value.unitPrice,
                  taxTreatment: _lineTreatments[e.key],
                ),
              )
              .toList(),
          discount: discount,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          status: documentStatusToString(_docStatus),
        );
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document saved')));
      setState(() {
        _allowPop = true;
        _saving = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save document. Your changes are still here. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _previewPdf(BuildContext context, org) async {
    if (_clientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a client first')));
      return;
    }

    final clientProvider = context.read<ClientProvider>();
    final client = _clientId != null
        ? clientProvider
              .clientsForOrganization(widget.editDoc?.orgId ?? org.id)
              .firstWhere(
                (c) => c.id == _clientId,
                orElse: () => Client(id: '', companyName: '—'),
              )
        : null;

    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    while (_lineTreatments.length < _items.length) {
      _lineTreatments.add(null);
    }
    final totals = computeTotalsV2(items: _items, org: org, discount: discount);

    final doc = QuoteflowDocument(
      id: 'preview',
      docType: documentTypeToString(_docType),
      docNumber: _docNumberCtrl.text.isEmpty ? 'PREVIEW' : _docNumberCtrl.text,
      issueDate: _issueDateCtrl.text.isEmpty ? todayISO() : _issueDateCtrl.text,
      dueDate: _dueDateCtrl.text.trim().isEmpty
          ? null
          : _dueDateCtrl.text.trim(),
      lineItems: _items
          .asMap()
          .entries
          .map(
            (e) => LineItem(
              description: e.value.description,
              quantity: e.value.quantity,
              unitPrice: e.value.unitPrice,
              taxTreatment: _lineTreatments[e.key],
            ),
          )
          .toList(),
      taxRate: totals.effectiveRate,
      discount: discount,
      subtotal: totals.subtotal,
      taxAmount: totals.taxAmount,
      total: totals.total,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      clientId: _clientId ?? '',
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final bytes = await PdfService.generatePdf(
        doc: doc,
        client: client,
        org: org,
      );
      if (context.mounted) {
        await PdfService.previewPdf(bytes, doc.docNumber);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF failed: $e')));
      }
    }
  }
}

/// Holds persistent controllers for a single line item row.
class _LineItemControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _LineItemControllers({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
