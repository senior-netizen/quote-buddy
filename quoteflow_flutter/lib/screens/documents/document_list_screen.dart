import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../providers/organization_provider.dart';
import '../../services/calculations.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/document_form_screen.dart';
import '../../widgets/reference_design.dart';
import 'document_detail_screen.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final _searchController = TextEditingController();
  bool _searchReset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A fresh push of this screen shouldn't inherit a stale search term.
    if (!_searchReset) {
      _searchReset = true;
      final provider = context.read<DocumentProvider>();
      if (provider.search.isNotEmpty) provider.setSearch('');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the active organization changes so the scoped list
    // (documents filtered by org) updates right away.
    context.watch<OrganizationProvider>();
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: ReferenceHeading(
              eyebrow: 'Library',
              title: 'Documents',
              subtitle:
                  'Create, manage and track all your business documents\nin one place.',
              action: FilledButton.icon(
                onPressed: () => _createDocument(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New'),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
              ),
            ),
          ),

          // Filter chips + Search — wrapped to prevent overflow
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                // Type filter chips — wrap
                Consumer<DocumentProvider>(
                  builder: (context, docProvider, _) {
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _filterChip('All', null, docProvider),
                        _filterChip('Quotes', DocumentType.quote, docProvider),
                        _filterChip(
                          'Invoices',
                          DocumentType.invoice,
                          docProvider,
                        ),
                        _filterChip(
                          'Credit notes',
                          DocumentType.creditNote,
                          docProvider,
                        ),
                        _filterChip(
                          'Debit notes',
                          DocumentType.debitNote,
                          docProvider,
                        ),
                        _filterChip(
                          'Receipts',
                          DocumentType.receipt,
                          docProvider,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Status filter chips
                Consumer<DocumentProvider>(
                  builder: (context, docProvider, _) {
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _statusChip('All statuses', null, docProvider),
                        _statusChip('Draft', DocumentStatus.draft, docProvider),
                        _statusChip('Sent', DocumentStatus.sent, docProvider),
                        _statusChip(
                          'Accepted',
                          DocumentStatus.accepted,
                          docProvider,
                        ),
                        _statusChip('Paid', DocumentStatus.paid, docProvider),
                        _statusChip(
                          'Overdue',
                          DocumentStatus.overdue,
                          docProvider,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            context.read<DocumentProvider>().setSearch(v),
                        decoration: InputDecoration(
                          hintText: 'Search number or client…',
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Filter documents',
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Document list
          Expanded(
            child: Consumer<DocumentProvider>(
              builder: (context, docProvider, _) {
                final docs = docProvider.documents;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          docProvider.search.isNotEmpty
                              ? 'No matches for your search.'
                              : 'No documents yet.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (docProvider.search.isEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _createDocument(context),
                            child: const Text('Create your first'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final client = docProvider.getClientForDocument(
                      doc.clientId,
                    );
                    final currency = context
                        .read<OrganizationProvider>()
                        .organization
                        .currency;
                    return _DocumentCard(
                      doc: doc,
                      clientName: client?.companyName ?? '—',
                      currency: currency,
                      onTap: () => _viewDocument(context, doc),
                      onPreview: () => _previewPdf(context, doc),
                      onDelete: () =>
                          _deleteDocument(context, doc, docProvider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createDocument(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String label, DocumentType? type, DocumentProvider p) {
    final selected = p.filter == type;
    return GestureDetector(
      onTap: () => p.setFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (type) {
                DocumentType.quote => Icons.description_outlined,
                DocumentType.invoice => Icons.receipt_long_outlined,
                DocumentType.creditNote => Icons.note_alt_outlined,
                DocumentType.debitNote => Icons.request_quote_outlined,
                DocumentType.receipt => Icons.receipt_outlined,
                _ => Icons.grid_view_rounded,
              },
              size: 14,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, DocumentStatus? status, DocumentProvider p) {
    final selected = p.statusFilter == status;
    final color = _statusColor(status);
    return GestureDetector(
      onTap: () => p.setStatusFilter(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: color, width: 1.5)
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Color _statusColor(DocumentStatus? status) {
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
      default:
        return AppColors.gray;
    }
  }

  void _showFilters() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<DocumentProvider>(
          builder: (context, provider, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter documents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _filterChip('All', null, provider),
                  for (final type in DocumentType.values)
                    _filterChip(type.label, type, provider),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _statusChip('All statuses', null, provider),
                  for (final status in DocumentStatus.values)
                    _statusChip(status.label, status, provider),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _createDocument(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DocumentFormScreen()));
  }

  void _viewDocument(BuildContext context, QuoteflowDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentId: doc.id),
      ),
    );
  }

  void _deleteDocument(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
  ) {
    docProvider.deleteDocument(doc.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${doc.docNumber}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await docProvider.createDocument(
              type: doc.type,
              docNumber: doc.docNumber,
              issueDate: doc.issueDate,
              dueDate: doc.dueDate,
              clientId: doc.clientId,
              lineItems: doc.lineItems,
              taxRate: doc.taxRate,
              discount: doc.discount,
              notes: doc.notes,
              status: doc.docStatus,
            );
          },
        ),
      ),
    );
  }

  Future<void> _previewPdf(BuildContext context, QuoteflowDocument doc) async {
    final orgProvider = context.read<OrganizationProvider>();
    final docProvider = context.read<DocumentProvider>();
    final client = docProvider.getClientForDocument(doc.clientId);

    try {
      final bytes = await PdfService.generatePdf(
        doc: doc,
        client: client,
        org: orgProvider.organization,
      );
      if (mounted) {
        await PdfService.previewPdf(bytes, doc.docNumber);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF failed: $e')));
      }
    }
  }
}

/// All existing row actions remain available through tap, menu and swipe.
class _DocumentCard extends StatelessWidget {
  final QuoteflowDocument doc;
  final String clientName, currency;
  final VoidCallback onTap, onPreview, onDelete;
  const _DocumentCard({
    required this.doc,
    required this.clientName,
    required this.currency,
    required this.onTap,
    required this.onPreview,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeColor = switch (doc.type) {
      DocumentType.quote => scheme.primary,
      DocumentType.invoice => const Color(0xFF20A35A),
      DocumentType.creditNote => const Color(0xFF8E4DE3),
      DocumentType.debitNote => const Color(0xFFDF8B20),
      DocumentType.receipt => const Color(0xFFDF5065),
    };
    final statusColor = switch (doc.effectiveStatus) {
      DocumentStatus.draft => AppColors.gray,
      DocumentStatus.sent => AppColors.blue,
      DocumentStatus.accepted => const Color(0xFF8A42D6),
      DocumentStatus.paid => const Color(0xFF199B5C),
      DocumentStatus.overdue => AppColors.red,
      DocumentStatus.declined => AppColors.orange,
    };
    final organizations = context.read<OrganizationProvider>().organizations;
    final company = organizations
        .where((o) => o.id == doc.orgId)
        .firstOrNull
        ?.name;
    return Slidable(
      key: ValueKey(doc.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReferenceIcon(
                  Icons.description_outlined,
                  color: typeColor,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              doc.type.shortLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              doc.docNumber,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Document actions',
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz,
                              size: 19,
                              color: scheme.onSurfaceVariant,
                            ),
                            onSelected: (action) =>
                                action == 'preview' ? onPreview() : onDelete(),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'preview',
                                child: Text('Preview PDF'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (company != null)
                        Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                company,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                formatDate(doc.issueDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatMoney(doc.total, currency),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          doc.effectiveStatus.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
