/// ZIMRA FDMS settings — device setup, fiscal day management, status dashboard.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/zimra_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/organization_provider.dart';
import 'fdms_readiness_screen.dart';
import '../credits_screen.dart';
import '../../services/zimra/zimra.dart';
import '../../widgets/reference_design.dart';

class ZimraSettingsScreen extends StatefulWidget {
  const ZimraSettingsScreen({super.key});

  @override
  State<ZimraSettingsScreen> createState() => _ZimraSettingsScreenState();
}

class _ZimraSettingsScreenState extends State<ZimraSettingsScreen> {
  Future<void> _refreshConfiguration(ZimraProvider zimra) async {
    final config = await zimra.fetchConfig();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          config != null
              ? 'Fiscalisation configuration updated.'
              : zimra.error ??
                    'Unable to refresh configuration. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zimra = context.watch<ZimraProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: referenceAppBar(
        context,
        'ZIMRA FDMS',
        subtitle: 'Fiscalisation & Compliance',
        actions: [
          IconButton(
            tooltip: 'Fiscalisation help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('ZIMRA fiscalisation'),
                content: const Text(
                  'Register using the device details supplied by the FDMS portal. Connected Test wallets use isolated test credits. Production requires ZIMRA approval and a connected live credit wallet. Closing a fiscal day submits its signed totals to ZIMRA.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ZIMRA approval readiness',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Guide checklist, captured Test evidence and regional submission.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const FdmsReadinessScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Prepare approval evidence'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (context.read<BillingProvider?>() != null)
            Card(
              child: ListTile(
                leading: const ReferenceIcon(
                  Icons.account_balance_wallet_outlined,
                ),
                title: const Text('Fiscalisation credits'),
                subtitle: const Text(
                  'View business balance or top up with Paynow',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreditsScreen()),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // ── Status card ──
          _buildStatusCard(zimra, scheme),
          const SizedBox(height: 16),

          if (zimra.isRegistered) ...[
            // ── Fiscalisation configuration ──
            _buildConfigCard(zimra, scheme),
            const SizedBox(height: 16),

            // ── Fiscal Day ──
            _buildFiscalDayCard(zimra, scheme),
            const SizedBox(height: 16),

            // ── Receipt History ──
            if (zimra.receiptHistory.isNotEmpty) ...[
              _buildReceiptHistoryCard(zimra, scheme),
              const SizedBox(height: 16),
            ],

            // ── Actions ──
            _buildActionsCard(zimra, scheme),
          ] else ...[
            // ── Registration ──
            _buildRegistrationCard(zimra, scheme),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fiscalisation configuration card (raw FDMS data — NOT the business tax
  // profile, which lives in Settings → Tax / Organization settings)
  // ---------------------------------------------------------------------------

  Widget _buildConfigCard(ZimraProvider zimra, ColorScheme scheme) {
    final effective = zimra.effectiveConfig;
    final hasFdmsConfig = zimra.config != null;
    final taxes = effective?.applicableTaxes ?? <ZimraTax>[];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_suggest_outlined,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fiscalisation Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ZIMRA tax configurations are supplied by the fiscal device configuration and cannot be changed locally.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              'Applicable ZIMRA taxes:',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            for (final t in taxes) _taxRow(zimra, scheme, t),
            if (taxes.isEmpty)
              Text(
                hasFdmsConfig
                    ? 'No applicable taxes returned by FDMS. Refresh the configuration.'
                    : 'Fetch the device configuration to load applicable taxes.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: taxes.isEmpty && hasFdmsConfig
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            if (zimra.manualTaxes.isNotEmpty) ...[
              const Text(
                'Legacy local taxes — not eligible for FDMS. Configure accounting taxes in Organisation settings.',
              ),
              for (final t in zimra.manualTaxes) _taxRow(zimra, scheme, t),
            ],
            if (hasFdmsConfig) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QR URL: ${(zimra.config!.qrUrl.isEmpty) ? "—" : zimra.config!.qrUrl}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                zimra.configFetchedAt == null
                    ? 'Last refresh: unknown'
                    : 'Last refresh: '
                          '${zimra.configFetchedAt!.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: zimra.isLoading
                    ? null
                    : () => _refreshConfiguration(zimra),
                icon: zimra.isFetchingConfig
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  zimra.isFetchingConfig
                      ? 'Refreshing...'
                      : (hasFdmsConfig ? 'Refresh now' : 'Fetch configuration'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One row of the applicable-taxes table: identity, rate, source badge
  /// (FDMS = returned by GetConfig, Manual = recorded by the user) and
  /// edit/delete actions for manual entries.
  Widget _taxRow(ZimraProvider zimra, ColorScheme scheme, ZimraTax t) {
    final percent = t.taxPercent == t.taxPercent.roundToDouble()
        ? t.taxPercent.toStringAsFixed(0)
        : t.taxPercent.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            t.isExempt ? Icons.block : Icons.percent,
            size: 14,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.isExempt
                  ? 'taxID ${t.taxId} — ${t.taxName} (exempt)'
                  : 'taxID ${t.taxId} — ${t.taxName} ($percent%)',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: t.isManual
                  ? scheme.tertiary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t.isManual ? 'Local (not FDMS)' : 'FDMS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: t.isManual ? scheme.tertiary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (t.isManual) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 16, color: scheme.error),
              tooltip: 'Remove tax',
              onPressed: () => _removeManualTax(zimra, t),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _removeManualTax(ZimraProvider zimra, ZimraTax tax) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove tax ${tax.taxId}?'),
        content: Text(
          '"${tax.taxName}" will no longer be offered when fiscalising. '
          'A later Refresh will restore any taxes ZIMRA returns for this '
          'device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final taxes = [
      for (final t in zimra.manualTaxes)
        if (t.taxId != tax.taxId) t,
    ];
    await zimra.setManualTaxes(taxes);
  }

  // ---------------------------------------------------------------------------
  // Status card
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard(ZimraProvider zimra, ColorScheme scheme) {
    final statusColor = zimra.error != null
        ? scheme.error
        : zimra.isRegistered
        ? (zimra.isOpen ? Colors.green : scheme.primary)
        : scheme.error;
    final statusText =
        zimra.error ??
        (zimra.isRegistered
            ? (zimra.isOpen ? 'Fiscal day OPEN' : 'Device registered')
            : 'Not registered');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    zimra.isRegistered
                        ? Icons.verified_outlined
                        : Icons.warning_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (zimra.isRegistered) ...[
              const SizedBox(height: 16),
              _buildDetailRow('Device ID', '${zimra.identity!.deviceId}'),
              _buildDetailRow('Serial', zimra.identity!.serialNumber),
              _buildDetailRow(
                'Environment',
                zimra.environment.name.toUpperCase(),
              ),
              _buildDetailRow('Receipts today', '${zimra.receiptCount}'),
              _buildDetailRow('Total receipts', '${zimra.globalReceiptCount}'),
              if (zimra.hasOfflineReceipts)
                _buildDetailRow(
                  'Offline queue',
                  '${zimra.offlineQueueLength} pending',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .35),
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: label == 'Environment'
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Fiscal day card
  // ---------------------------------------------------------------------------

  Widget _buildFiscalDayCard(ZimraProvider zimra, ColorScheme scheme) {
    final isOpen = zimra.isOpen;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOpen ? Icons.calendar_today : Icons.event_busy,
                  color: isOpen ? Colors.green : scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Fiscal Day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!zimra.dayState.isClosed) ...[
              if (!isOpen)
                Text(
                  zimra.status == FiscalDayStatus.fiscalDayCloseFailed
                      ? 'ZIMRA could not close this day. Retry closing after resolving any errors.'
                      : 'ZIMRA is processing the day closure. Check status to confirm.',
                ),
              _buildDetailRow('Day #', '${zimra.dayState.fiscalDayNo ?? "?"}'),
              _buildDetailRow('Date', zimra.dayState.fiscalDayDate ?? '?'),
              _buildDetailRow('Receipts', '${zimra.dayState.receiptCounter}'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: zimra.isLoading
                      ? null
                      : zimra.status == FiscalDayStatus.fiscalDayCloseInitiated
                      ? () => zimra.refreshStatus()
                      : () => _confirmCloseDay(zimra),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: Text(
                    zimra.status == FiscalDayStatus.fiscalDayCloseInitiated
                        ? 'Check Closure Status'
                        : 'Close Fiscal Day',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                ),
              ),
            ] else ...[
              Text(
                'No fiscal day is open. Open a day before issuing receipts.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: zimra.isLoading
                      ? null
                      : () async {
                          try {
                            await zimra.openDay();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Fiscal day ${zimra.dayState.fiscalDayNo} opened',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: scheme.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Open Fiscal Day'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCloseDay(ZimraProvider zimra) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Fiscal Day?'),
        content: const Text(
          'This will sign and submit the day counters to ZIMRA. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Close Day'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await zimra.closeDay();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                zimra.dayState.isClosed
                    ? 'Fiscal day closed successfully'
                    : 'Closure submitted to ZIMRA. Check closure status to confirm.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
          if (e.toString().contains('DAY010') || zimra.dayState.hasRedErrors) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Fiscal day has red validation errors'),
                content: SingleChildScrollView(
                  child: Text(
                    [
                      'Review the affected receipts. The FDMS CloseDay API does not support force closing; contact the ZIMRA administrator.',
                      ...zimra.dayState.redErrors,
                      ...zimra.receiptHistory.expand(
                        (r) => r.response.validationErrors.map(
                          (v) =>
                              'Receipt ${r.response.receiptId ?? "unknown"}: ${v.code} (${v.color}) ${v.description}',
                        ),
                      ),
                    ].join('\n'),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Receipt history
  // ---------------------------------------------------------------------------

  Widget _buildReceiptHistoryCard(ZimraProvider zimra, ColorScheme scheme) {
    final history = zimra.receiptHistory.take(10).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Recent Receipts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final receipt in history) ...[
              if (receipt != history.first) const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.check_circle,
                  color: receipt.response.validationErrors.any((e) => e.isRed)
                      ? scheme.error
                      : receipt.response.validationErrors.any((e) => e.isYellow)
                      ? Colors.orange
                      : Colors.green,
                  size: 18,
                ),
                title: Text(
                  '${receipt.response.receiptId ?? 'Submitted'}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  [
                    receipt.response.serverDate ?? '',
                    ...receipt.response.validationErrors.map(
                      (e) => '${e.code} (${e.color}): ${e.userMessage}',
                    ),
                  ].join('\n'),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                trailing: receipt.qrData != null
                    ? Icon(Icons.qr_code, size: 16, color: scheme.primary)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions card (deregister)
  // ---------------------------------------------------------------------------

  Widget _buildActionsCard(ZimraProvider zimra, ColorScheme scheme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(Icons.delete_outline, color: scheme.error, size: 20),
        title: const Text('De-register Device'),
        subtitle: const Text(
          'Remove device credentials and fiscal state. Saved approval evidence is retained.',
        ),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('De-register Device?'),
              content: const Text(
                'This removes device credentials and fiscal state. Saved approval evidence is retained. You will need to register a device to fiscalise again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  child: const Text('De-register'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await zimra.clearDevice();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Device de-registered')),
              );
            }
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Registration card
  // ---------------------------------------------------------------------------

  Widget _buildRegistrationCard(ZimraProvider zimra, ColorScheme scheme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.app_registration, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Register Device',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Register this device with ZIMRA\'s FDMS to start fiscalising receipts. '
              'You need a device ID, serial number, and activation key from the '
              'FDMS portal.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            // Link to test portal
            TextButton.icon(
              onPressed: () {
                // Would open URL — just show info
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Visit fdmsops.zimra.co.zw/fdms-public/add-device '
                      'to register a test device',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open FDMS Test Portal'),
            ),
            const SizedBox(height: 12),
            _RegistrationForm(zimra: zimra),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registration form
// ---------------------------------------------------------------------------

class _RegistrationForm extends StatefulWidget {
  final ZimraProvider zimra;
  const _RegistrationForm({required this.zimra});

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<_RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _activationKeyCtrl = TextEditingController();
  final _modelNameCtrl = TextEditingController();
  final _modelVersionCtrl = TextEditingController();
  DateTime? _issuedAt;
  ZimraEnvironment _environment = ZimraEnvironment.test;

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _serialCtrl.dispose();
    _activationKeyCtrl.dispose();
    _modelNameCtrl.dispose();
    _modelVersionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment toggle
          SegmentedButton<ZimraEnvironment>(
            segments: const [
              ButtonSegment(value: ZimraEnvironment.test, label: Text('Test')),
              ButtonSegment(
                value: ZimraEnvironment.production,
                label: Text('Production'),
              ),
            ],
            selected: {_environment},
            onSelectionChanged: (s) => setState(() => _environment = s.first),
          ),
          const SizedBox(height: 16),

          // Device ID
          TextFormField(
            controller: _deviceIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Device ID',
              hintText: 'e.g. 12345',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if ((int.tryParse(v) ?? 0) <= 0)
                return 'Enter a positive device ID';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Serial number
          TextFormField(
            controller: _serialCtrl,
            decoration: const InputDecoration(
              labelText: 'Serial Number',
              hintText: 'e.g. MYPOS001',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) =>
                v == null ||
                    v.trim().isEmpty ||
                    RegExp(r'\s').hasMatch(v.trim())
                ? 'Use the serial number from FDMS, without spaces'
                : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _modelNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Device Model Name',
              hintText: 'Exactly as shown in the ZIMRA portal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _modelVersionCtrl,
            decoration: const InputDecoration(
              labelText: 'Device Model Version',
              hintText: 'Exactly as shown in the ZIMRA portal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          // Activation key
          TextFormField(
            controller: _activationKeyCtrl,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Activation Key',
              hintText: '8-character key from portal',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length != 8) return 'Must be 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          const Text(
            'FDMS activation credentials must be used within 24 hours. Record the issuance time from the FDMS email; request new credentials if expired.',
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                firstDate: now.subtract(const Duration(days: 30)),
                lastDate: now,
                initialDate: now,
              );
              if (date == null || !mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null && mounted)
                setState(
                  () => _issuedAt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  ),
                );
            },
            icon: const Icon(Icons.schedule),
            label: Text(
              _issuedAt == null
                  ? 'Record credential issuance time'
                  : 'Issued: $_issuedAt',
            ),
          ),
          if (_environment == ZimraEnvironment.production)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Production requires completed Test evidence, your recorded external ZIMRA approval reference and fresh live credentials. QuoteFlow account approval is separate.',
              ),
            ),
          // Register button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.zimra.isLoading ? null : _register,
              icon: widget.zimra.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Register Device'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.zimra.registerDevice(
        device: ZimraDeviceIdentity(
          deviceId: int.parse(_deviceIdCtrl.text.trim()),
          serialNumber: _serialCtrl.text.trim(),
          modelName: _modelNameCtrl.text.trim(),
          modelVersion: _modelVersionCtrl.text.trim(),
        ),
        activationKey: _activationKeyCtrl.text.trim(),
        environment: _environment,
        credentialsIssuedAt: _issuedAt,
        businessTin: context.read<OrganizationProvider?>()?.organization.tin,
      );
      _activationKeyCtrl.clear();

      // Also fetch config after registration
      await widget.zimra.fetchConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device registered successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
