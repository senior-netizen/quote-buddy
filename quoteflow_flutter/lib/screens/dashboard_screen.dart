import 'package:flutter/material.dart';
import '../providers/business_account_provider.dart';
import 'business_account_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/client_provider.dart';
import '../providers/document_provider.dart';
import '../providers/organization_provider.dart';
import '../services/calculations.dart';
import '../theme/app_theme.dart';
import '../widgets/document_form_screen.dart';
import '../widgets/reference_design.dart';
import 'documents/document_detail_screen.dart';
import 'documents/document_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final clientProvider = context.watch<ClientProvider>();
    final org = context.watch<OrganizationProvider>().organization;
    final currency = org.currency;
    final recent = docProvider.recentDocuments(8);
    final isNarrow = MediaQuery.of(context).size.width < 500;
    final pad = isNarrow ? 16.0 : 24.0;
    final scheme = Theme.of(context).colorScheme;
    final totalClients = docProvider.showAll
        ? clientProvider.allClients.length
        : clientProvider.clients.length;
    final outstanding = docProvider.outstandingValue;
    final overdue = docProvider.overdueDocuments;
    final showAll = docProvider.showAll;
    List<double> seriesFor(DocumentType type, bool amount) {
      final now = DateTime.now();
      return List.generate(6, (index) {
        final month = DateTime(now.year, now.month - 5 + index);
        return docProvider.allDocuments
            .where((doc) {
              final date = DateTime.tryParse(doc.issueDate);
              return (showAll || doc.orgId == org.id) &&
                  doc.type == type &&
                  date?.year == month.year &&
                  date?.month == month.month;
            })
            .fold<double>(0, (sum, doc) => sum + (amount ? doc.total : 1));
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReferenceHeading(
              eyebrow: '',
              title: 'Good to see you.',
              subtitle: "Here's what's happening with your business today.",
              action: IconButton.filled(
                onPressed: () => _newDoc(context),
                tooltip: 'New document',
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF141F34),
                ),
              ),
            ),
            SizedBox(height: isNarrow ? 18 : 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('This company'),
                  avatar: Icon(
                    Icons.business_outlined,
                    size: 15,
                    color: showAll ? scheme.onSurfaceVariant : scheme.onPrimary,
                  ),
                  showCheckmark: false,
                  selected: !showAll,
                  selectedColor: scheme.primary,
                  backgroundColor: scheme.surface,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: showAll ? scheme.onSurfaceVariant : scheme.onPrimary,
                  ),
                  onSelected: (_) {
                    docProvider.setShowAll(false);
                    clientProvider.setShowAll(false);
                  },
                ),
                ChoiceChip(
                  label: const Text('All companies'),
                  avatar: Icon(
                    Icons.groups_outlined,
                    size: 15,
                    color: showAll ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  showCheckmark: false,
                  selected: showAll,
                  selectedColor: scheme.primary,
                  backgroundColor: scheme.surface,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: showAll ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  onSelected: (_) {
                    docProvider.setShowAll(true);
                    clientProvider.setShowAll(true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Independent statistic cards mirror the supplied reference.
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Quotations',
                        docProvider.quotesCount.toString(),
                        isNarrow,
                        scheme,
                        series: seriesFor(DocumentType.quote, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Invoices',
                        docProvider.invoicesCount.toString(),
                        isNarrow,
                        scheme,
                        series: seriesFor(DocumentType.invoice, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Quoted value',
                        formatMoney(docProvider.quoteValue, currency),
                        isNarrow,
                        scheme,
                        series: seriesFor(DocumentType.quote, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Invoiced value',
                        formatMoney(docProvider.invoiceValue, currency),
                        isNarrow,
                        scheme,
                        series: seriesFor(DocumentType.invoice, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isNarrow ? 16 : 24),
            // Revenue chart
            if (docProvider.allDocuments.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue collected · Last 6 months',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _RevenueChart(
                        monthlyRevenue: docProvider.monthlyRevenue,
                        currency: currency,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isNarrow ? 20 : 28),
            ],

            // Quick stats row
            if (docProvider.allDocuments.isNotEmpty) ...[
              if (isNarrow)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _quickStatCard(
                            'Conversion Rate',
                            '${(docProvider.conversionRate * 100).toStringAsFixed(0)}%',
                            Icons.trending_up,
                            AppColors.green,
                            scheme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickStatCard(
                            'Awaiting payment',
                            formatMoney(outstanding, currency),
                            Icons.hourglass_bottom,
                            AppColors.orange,
                            scheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _quickStatCard(
                            'Total Documents',
                            docProvider.allDocuments.length.toString(),
                            Icons.description_outlined,
                            scheme.primary,
                            scheme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickStatCard(
                            'Total Clients',
                            totalClients.toString(),
                            Icons.people_outline,
                            AppColors.blue,
                            scheme,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _quickStatCard(
                        'Conversion Rate',
                        '${(docProvider.conversionRate * 100).toStringAsFixed(0)}%',
                        Icons.trending_up,
                        AppColors.green,
                        scheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStatCard(
                        'Awaiting payment',
                        formatMoney(outstanding, currency),
                        Icons.hourglass_bottom,
                        AppColors.orange,
                        scheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStatCard(
                        'Total Documents',
                        docProvider.allDocuments.length.toString(),
                        Icons.description_outlined,
                        scheme.primary,
                        scheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStatCard(
                        'Total Clients',
                        totalClients.toString(),
                        Icons.people_outline,
                        AppColors.blue,
                        scheme,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: isNarrow ? 20 : 28),
            ],

            // Overdue summary
            if (overdue.isNotEmpty) ...[
              _OverdueCard(
                docs: overdue,
                currency: currency,
                onViewAll: () => _openOverdueList(context),
              ),
              SizedBox(height: isNarrow ? 20 : 28),
            ],

            // Recent documents
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent documents',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DocumentListScreen(),
                      ),
                    );
                  },
                  child: const Text('View all →'),
                ),
              ],
            ),

            SizedBox(height: isNarrow ? 8 : 12),

            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: recent.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(isNarrow ? 32 : 48),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'No documents yet.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _newDoc(context),
                              child: const Text('Create your first'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Header — hide on very narrow to save space
                        if (!isNarrow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'NUMBER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'TYPE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'CLIENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'TOTAL',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Rows
                        for (int i = 0; i < recent.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: scheme.outlineVariant),
                          isNarrow
                              ? _recentRowCompact(
                                  context,
                                  recent[i],
                                  docProvider,
                                  currency,
                                )
                              : _recentRow(
                                  context,
                                  recent[i],
                                  docProvider,
                                  currency,
                                ),
                        ],
                      ],
                    ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _newDoc(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DocumentFormScreen()));
  }

  /// Opens the Documents list pre-filtered to Overdue, then clears the
  /// filter again once the user comes back to the dashboard.
  Future<void> _openOverdueList(BuildContext context) async {
    final docProvider = context.read<DocumentProvider>();
    docProvider.setStatusFilter(DocumentStatus.overdue);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DocumentListScreen()));
    docProvider.setStatusFilter(null);
  }

  Widget _statCard(
    String label,
    String value,
    bool compact,
    ColorScheme scheme, {
    List<double> series = const [],
  }) {
    final color = switch (label) {
      'Invoices' => const Color(0xFF23A46A),
      'Quoted value' => const Color(0xFF9B4AE9),
      'Invoiced value' => const Color(0xFFF39629),
      _ => scheme.primary,
    };
    final icon = label.contains('value')
        ? Icons.payments_outlined
        : Icons.description_outlined;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReferenceIcon(icon, color: color, size: compact ? 29 : 38),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 21 : 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ),
            if (series.length >= 2) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      series[series.length - 2] == 0
                          ? (series.last == 0 ? 'No change' : 'New this month')
                          : '${(((series.last - series[series.length - 2]) / series[series.length - 2]) * 100).round()}% vs last month',
                      style: TextStyle(
                        fontSize: 8,
                        color: series.last >= series[series.length - 2]
                            ? const Color(0xFF199B5C)
                            : AppColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ReferenceSparkline(values: series, color: color),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Full-width row for wide screens.
  Widget _recentRow(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider docProvider,
    String currency,
  ) {
    final client = docProvider.getClientForDocument(doc.clientId);
    final statusColor = _statusColor(doc.effectiveStatus);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: doc.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                doc.docNumber,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  doc.type.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  doc.effectiveStatus.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                client?.companyName ?? '—',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                formatMoney(doc.total, currency),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact card-style row for narrow screens.
  Widget _recentRowCompact(
    BuildContext context,
    QuoteflowDocument doc,
    DocumentProvider provider,
    String currency,
  ) {
    final client = provider.getClientForDocument(doc.clientId);
    final colors = Theme.of(context).colorScheme,
        status = _statusColor(doc.effectiveStatus);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(documentId: doc.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ReferenceIcon(
              Icons.description_outlined,
              color: doc.type == DocumentType.invoice
                  ? const Color(0xFF1BA966)
                  : colors.primary,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.docNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client?.companyName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDate(doc.issueDate),
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(doc.total, currency),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      doc.effectiveStatus.label,
                      style: TextStyle(
                        fontSize: 9,
                        color: status,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

/// Simple revenue bar chart
class _RevenueChart extends StatelessWidget {
  final Map<String, double> monthlyRevenue;
  final String currency;

  const _RevenueChart({required this.monthlyRevenue, required this.currency});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = monthlyRevenue.entries.toList();
    final maxValue = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return Center(
        child: Text(
          'No revenue data yet',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = entries[groupIndex];
              final monthIdx = int.tryParse(entry.key.split('-').last) ?? 1;
              return BarTooltipItem(
                '${months[monthIdx - 1]}\n${formatMoney(rod.toY, currency)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < entries.length) {
                  final monthIdx =
                      int.tryParse(entries[idx].key.split('-').last) ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      months[monthIdx - 1],
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(0)}k'
                      : value.toStringAsFixed(0),
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        barGroups: entries.asMap().entries.map((entry) {
          final idx = entry.key;
          final value = entry.value.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: value,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    scheme.primary.withValues(alpha: .12),
                    scheme.primary,
                  ],
                ),
                width: 28,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

int _daysOverdue(QuoteflowDocument doc) {
  final due = DateTime.tryParse(doc.dueDate ?? '');
  if (due == null) return 0;
  final now = DateTime.now();
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(dueDay).inDays;
}

/// Summary card listing every invoice that is currently past due, most
/// urgent first, with days overdue and the amount still owed.
class _OverdueCard extends StatelessWidget {
  final List<QuoteflowDocument> docs;
  final String currency;
  final VoidCallback onViewAll;

  const _OverdueCard({
    required this.docs,
    required this.currency,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = scheme.error;
    final total = docs.fold<double>(0, (sum, d) => sum + d.total);
    final shown = docs.length > 5 ? docs.take(5).toList() : docs;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.schedule, size: 20, color: error),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVERDUE INVOICES',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${docs.length} unpaid · ${formatMoney(total, currency)} outstanding',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          for (final doc in shown) ...[
            _OverdueRow(doc: doc, currency: currency),
            Divider(height: 1, color: scheme.outlineVariant),
          ],
          if (docs.length > shown.length)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'Show all ${docs.length} overdue invoices →',
                    style: TextStyle(color: error, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'View in documents →',
                    style: TextStyle(color: error, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  final QuoteflowDocument doc;
  final String currency;

  const _OverdueRow({required this.doc, required this.currency});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = scheme.error;
    final client = context.read<DocumentProvider>().getClientForDocument(
      doc.clientId,
    );
    final days = _daysOverdue(doc);
    final daysLabel = days > 0
        ? '$days ${days == 1 ? 'day' : 'days'} overdue'
        : 'Overdue';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: doc.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.docNumber,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    client?.companyName ?? '—',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daysLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(doc.total, currency),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
