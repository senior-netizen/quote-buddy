import '../../providers/client_provider.dart';
import '../../widgets/customer_form.dart';
import '../../services/fiscal_buyer_mapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/organization_provider.dart';
import '../../services/calculations.dart';
import '../documents/document_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final currency = context
        .watch<OrganizationProvider>()
        .organization
        .currency;
    final clientProvider = context.read<DocumentProvider>();
    final client = context.watch<ClientProvider>().getClient(widget.clientId);

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client')),
        body: const Center(child: Text('Client not found')),
      );
    }

    final clientDocs = clientProvider.getDocumentsForClient(widget.clientId);
    final isNarrow = MediaQuery.of(context).size.width < 500;
    final pad = isNarrow ? 16.0 : 24.0;

    // Calculate totals
    final totalQuoted = clientDocs
        .where((d) => d.type == DocumentType.quote)
        .fold<double>(0, (s, d) => s + d.total);
    final totalInvoiced = clientDocs
        .where((d) => d.type == DocumentType.invoice)
        .fold<double>(0, (s, d) => s + d.total);
    final totalPaid = clientDocs
        .where((d) => d.status == DocumentStatus.paid)
        .fold<double>(0, (s, d) => s + d.total);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(client.companyName),
        actions: [
          IconButton(
            onPressed: () => showCustomerForm(context, customer: client),
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Edit Customer",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client avatar + name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      client.companyName.isNotEmpty
                          ? client.companyName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    client.companyName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact info
            _sectionTitle('BASIC DETAILS'),
            const SizedBox(height: 8),
            _infoCard([
              _infoRow(
                Icons.person_outline,
                "Customer type",
                client.customerType == "business" ? "Business" : "Individual",
              ),
              if (client.registeredName != null)
                _infoRow(
                  Icons.business,
                  "Registered name",
                  client.registeredName!,
                ),
              if (client.tradeName != null)
                _infoRow(Icons.store, "Trade name", client.tradeName!),
              if (client.email != null)
                _infoRow(Icons.email_outlined, 'Email', client.email!),
              if (client.phone != null)
                _infoRow(Icons.phone_outlined, 'Phone', client.phone!),
              if (client.address != null)
                _infoRow(
                  Icons.location_on_outlined,
                  'Address',
                  client.address!,
                ),
              if (client.email == null &&
                  client.phone == null &&
                  client.address == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No contact information added.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
            ]),

            const SizedBox(height: 24),

            _sectionTitle('TAX & FISCAL DETAILS'),
            _infoCard([
              _infoRow(Icons.numbers, 'TIN', client.tin ?? 'Not provided'),
              _infoRow(
                Icons.receipt_outlined,
                'VAT Registered',
                client.vatRegistered ? 'Yes' : 'No',
              ),
              if (client.vatRegistered)
                _infoRow(
                  Icons.numbers,
                  'VAT Registration Number',
                  client.vatNumber ?? 'Not provided',
                ),
              if (FiscalBuyerMapper.problems(client).isNotEmpty)
                const Text('Fiscal details incomplete'),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('ADDRESS'),
            _infoCard([
              Text(
                client.formattedAddress.isEmpty
                    ? 'Not provided'
                    : client.formattedAddress,
              ),
            ]),
            const SizedBox(height: 24),
            // Stats
            _sectionTitle('STATS'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total documents',
                    clientDocs.length.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Quoted',
                    formatMoney(totalQuoted, currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Invoiced',
                    formatMoney(totalInvoiced, currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statCard('Paid', formatMoney(totalPaid, currency)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Outstanding',
                    formatMoney(totalInvoiced - totalPaid, currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('Documents', clientDocs.length.toString()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Documents list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('DOCUMENTS'),
                Text(
                  '${clientDocs.length} total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (clientDocs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                child: Center(
                  child: Text(
                    'No documents for this client yet.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...clientDocs.map(
                (doc) => _DocumentTile(doc: doc, currency: currency),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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

  Widget _infoCard(List<Widget> children) {
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
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
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final QuoteflowDocument doc;
  final String currency;

  const _DocumentTile({required this.doc, required this.currency});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(doc.effectiveStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(documentId: doc.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: doc.type == DocumentType.quote
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc.type.shortLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: doc.type == DocumentType.quote
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Doc info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.docNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(doc.issueDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
              const SizedBox(width: 12),
              // Amount
              Text(
                formatMoney(doc.total, currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
