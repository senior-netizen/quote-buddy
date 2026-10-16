import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../providers/billing_provider.dart';
import '../providers/business_account_provider.dart';
import 'business_account_screen.dart';
import '../providers/organization_provider.dart';
import '../widgets/reference_design.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});
  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen>
    with WidgetsBindingObserver {
  final _accessCode = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _purchaseForm = GlobalKey<FormState>();
  String _method = 'ecocash';
  final Map<String, Map<String, dynamic>> _prepared = {};
  String _activeTin = '';
  Timer? _paymentTimer;
  bool _foreground = true;
  final Map<String, int> _checks = {};

  bool _pending(Map order) => const {
    'pending',
    'created',
    'sent',
    'ok',
    'initiating',
    'initiationunknown',
  }.contains((order['status'] as String? ?? '').toLowerCase());

  Future<void> _checkPending() async {
    if (!mounted ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true))
      return;
    final tin = _activeTin;
    final billing = context.read<BillingProvider>();
    if (billing.isBusy(tin)) return;
    final payments = (billing.wallet(tin)?['payments'] as List? ?? [])
        .whereType<Map>();
    for (final payment in payments) {
      final reference = payment['reference'] as String?;
      if (reference == null || !_pending(payment)) continue;
      final checks = _checks[reference] ?? 0;
      if (checks >= 60) continue;
      _checks[reference] = checks + 1;
      await billing.verifyPayment(tin, reference);
      if (mounted && _activeTin == tin) {
        setState(() => _prepared.remove(tin));
      }
      break; // One verified request at a time; pause after eight minutes.
    }
    if (mounted && _activeTin == tin) await billing.refresh(tin);
  }

  String _demoRun = const Uuid().v4();
  String? _demoReceipt;
  Map<String, dynamic>? _demo;

  Future<void> _runDemo(
    String tin,
    BillingProvider billing, {
    bool replay = false,
  }) async {
    if (!replay) _demoReceipt = const Uuid().v4();
    final receipt = _demoReceipt;
    if (receipt == null) return;
    final result = await billing.simulateDeduction(tin, _demoRun, receipt);
    if (mounted && _activeTin == tin && result != null) {
      setState(() => _demo = result);
    }
  }

  Widget _stat(String label, Object? value, ColorScheme colors) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '${value ?? 0}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    ),
  );
  Widget _methodOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool busy,
    ColorScheme colors,
  ) {
    final selected = _method == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: busy ? null : () => setState(() => _method = value),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: value == 'ecocash'
                          ? const Color(0xFF087BFA)
                          : value == 'telecash'
                          ? const Color(0xFFE9214A)
                          : const Color(0xFF242456),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceCard(Map<String, dynamic> wallet, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF124DE0), Color(0xFF0879D0)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storage_rounded, color: Colors.white),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Available credits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${wallet['available']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Purchased credits never expire.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (context) => SingleChildScrollView(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit usage',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ListTile(
                          title: const Text('Used'),
                          trailing: Text('${wallet['used'] ?? 0}'),
                        ),
                        ListTile(
                          title: const Text('Pending verification'),
                          trailing: Text('${wallet['reserved'] ?? 0}'),
                        ),
                        ListTile(
                          title: const Text('Purchased'),
                          trailing: Text('${wallet['purchased'] ?? 0}'),
                        ),
                        const Text(
                          'Pending credits are reserved until the fiscal submission is reconciled. Retries do not use another credit.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('View usage'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Used', wallet['used'], colors),
              const SizedBox(width: 6),
              _stat('Pending', wallet['reserved'], colors),
              const SizedBox(width: 6),
              _stat('Purchased', wallet['purchased'], colors),
            ],
          ),
          if ((wallet['available'] as int) <= 10)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Almost out of credits. Top up before your next fiscalisation.',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paymentTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _checkPending(),
    );
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _accessCode.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _activeTin.isNotEmpty) {
      context.read<BillingProvider>().refresh(_activeTin);
    }
  }

  Future<void> _openPayment(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'www.paynow.co.zw' ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Paynow. Use Copy payment link instead.',
          ),
        ),
      );
    }
  }

  void _showHelp() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Your business access code'),
      content: const Text(
        'A designated Squirrellabs administrator verifies your business TIN and ZIMRA device assignment, then issues your access code. Keep it private. It is separate from your ZIMRA activation key and Paynow integration key.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Widget _helpCard() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: .06),
          Theme.of(context).colorScheme.primary.withValues(alpha: .13),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEED HELP?',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Where to get your\nbusiness access code',
                style: TextStyle(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your access code is provided by a Squirrellabs administrator after your business is verified.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _showHelp,
                label: const Text('Learn more'),
                icon: const Icon(Icons.open_in_new, size: 17),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: .2,
          child: Container(
            width: 92,
            height: 154,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .16),
                  blurRadius: 18,
                  offset: const Offset(3, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FittedBox(
                  child: Text(
                    'QuoteFlow',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 5,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 7),
                Container(
                  width: 45,
                  height: 5,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '••••••',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _payment(
    Map<String, dynamic> order,
    String tin,
    BillingProvider billing,
  ) {
    final url = order['checkoutUrl'] as String?;
    final reference = order['reference'] as String;
    final status = order['status'] as String? ?? 'Pending';
    final paid = const {
      'paid',
      'awaiting delivery',
      'delivered',
    }.contains(status.toLowerCase());
    final awaiting = _pending(order);
    final paused = (_checks[reference] ?? 0) >= 60;
    final payable = const {
      'pending',
      'created',
      'sent',
      'ok',
    }.contains(status.toLowerCase());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'US\$5.00 · 500 credits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              paid
                  ? 'Payment confirmed · credits added'
                  : payable
                  ? 'Awaiting payment confirmation'
                  : status == 'InitiationUnknown' || status == 'Initiating'
                  ? 'Payment request awaiting confirmation'
                  : 'Payment ${status.toLowerCase()}',
            ),
            if (order['method'] == 'ecocash' && payable)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Approve the EcoCash prompt on your phone, then check payment status. Never enter your wallet PIN in QuoteFlow.',
                ),
              ),
            SelectableText(
              'Reference: $reference',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (awaiting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  paused
                      ? 'Automatic checks paused. Check payment status or contact support with your reference before starting another purchase.'
                      : 'Waiting for approval. We check payment status automatically. You can leave this page and resume from Payment activity.',
                ),
              ),
            if (const {
              'cancelled',
              'failed',
              'disputed',
            }.contains(status.toLowerCase()))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'This payment has not added credits. Check your wallet or bank statement before starting a new purchase.',
                ),
              ),
            if (status == 'InitiationUnknown' || status == 'Initiating')
              const Text(
                'Checkout has not been confirmed. Refresh or contact support before making another purchase.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (url != null && payable)
                  FilledButton(
                    onPressed: () => _openPayment(url),
                    child: const Text('Open Paynow'),
                  ),
                if (url != null && payable)
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment link copied.')),
                        );
                      }
                    },
                    child: const Text('Copy payment link'),
                  ),
                if (!paid)
                  OutlinedButton(
                    onPressed: billing.isBusy(tin)
                        ? null
                        : () async {
                            _checks[reference] = 0;
                            await billing.verifyPayment(tin, reference);
                            if (mounted) setState(() => _prepared.remove(tin));
                          },
                    child: const Text('Check payment status'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().organization;
    final tin = org.tin?.trim() ?? '';
    if (_activeTin != tin) {
      _demoRun = const Uuid().v4();
      _demoReceipt = null;
      _demo = null;
      _accessCode.clear();
      _phone.clear();
      _email.clear();
      _activeTin = tin;
    }
    final billing = context.watch<BillingProvider>();
    final wallet = billing.wallet(tin);
    final busy = billing.isBusy(tin);
    final error = billing.error(tin);
    final colors = Theme.of(context).colorScheme;
    final isTest = wallet?['mode'] == 'test';
    final payments = (wallet?['payments'] as List? ?? [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final prepared = _prepared[tin];
    if (prepared != null &&
        !payments.any((p) => p['reference'] == prepared['reference'])) {
      payments.insert(0, prepared);
    }
    final hasPendingPayment = payments.any(_pending);
    return Scaffold(
      appBar: referenceAppBar(
        context,
        'Fiscalisation credits',
        subtitle: 'ZIMRA FDMS',
        actions: [
          IconButton(
            tooltip: 'Access code help',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          if (wallet != null)
            IconButton(
              tooltip: 'Refresh credits',
              onPressed: busy
                  ? null
                  : () async {
                      await billing.refresh(tin);
                      if (mounted) setState(() => _prepared.remove(tin));
                    },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const ReferenceIcon(Icons.apartment_rounded, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tin.isEmpty
                                  ? 'Add your business TIN in organization settings first.'
                                  : 'Business TIN: $tin',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (wallet != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.brightness == Brightness.dark
                                      ? const Color(0xFF123D30)
                                      : const Color(0xFFE1F6EC),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color:
                                          colors.brightness == Brightness.dark
                                          ? const Color(0xFF8CE4BD)
                                          : const Color(0xFF08744F),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Connected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              colors.brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF8CE4BD)
                                              : const Color(0xFF08744F),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ReferenceNotice(
                isTest
                    ? 'Credits are shared across this business’s devices and users. Accepted ZIMRA test documents use test credits; production credits are unaffected.'
                    : 'Credits are shared across this business’s devices and users. Test and production balances are separate.',
              ),
              const SizedBox(height: 20),
              if (context.watch<BusinessAccountProvider?>() != null &&
                  wallet == null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'New business?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create an account, verify your email and submit your business for approval. Existing access codes still work below.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const BusinessAccountScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Register or sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (wallet == null && RegExp(r'^\d{10}$').hasMatch(tin)) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business access code',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reconnect with your business access code to restore your balance and pending payments, including purchases started on another device.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _accessCode,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Business access code',
                            hintText: 'Enter business access code',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (await billing.connect(
                                      tin,
                                      _accessCode.text,
                                    )) {
                                      _accessCode.clear();
                                    }
                                  },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(child: Text('Connect business')),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (wallet == null) ...[const SizedBox(height: 24), _helpCard()],
              if (wallet != null) ...[
                _balanceCard(wallet, colors),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Purchase credits',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.bolt_rounded),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '500 credits · US\$5.00',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose your payment method. Your balance updates after Paynow confirms payment.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Form(
                          key: _purchaseForm,
                          child: Column(
                            children: [
                              for (final option in const [
                                (
                                  'ecocash',
                                  'EcoCash',
                                  'Approve a payment prompt on your phone',
                                  Icons.phone_android,
                                ),
                                (
                                  'telecash',
                                  'Telecash',
                                  'Continue securely to Paynow',
                                  Icons.phone_iphone,
                                ),
                                (
                                  'bank',
                                  'Bank / card',
                                  'Complete payment on Paynow',
                                  Icons.account_balance_outlined,
                                ),
                              ])
                                _methodOption(
                                  option.$1,
                                  option.$2,
                                  option.$3,
                                  option.$4,
                                  busy,
                                  colors,
                                ),
                              if (_method == 'ecocash') ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'EcoCash mobile number',
                                    hintText: '0771234567 or +263771234567',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  validator: (value) =>
                                      RegExp(
                                        r'^(?:0|\+263)7[78]\d{7}$',
                                      ).hasMatch(
                                        (value ?? '').replaceAll(
                                          RegExp(r'[\s()-]'),
                                          '',
                                        ),
                                      )
                                      ? null
                                      : 'Enter a valid EcoCash number',
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Payment email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) =>
                                      RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch((value ?? '').trim())
                                      ? null
                                      : 'Enter a valid email address',
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'EcoCash will ask you to approve US\$5.00 on your phone. Enter your PIN only in the EcoCash prompt.',
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (hasPendingPayment)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'You have a pending purchase. Continue or check it in Recent activity below before buying again.',
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy || hasPendingPayment
                                ? null
                                : () async {
                                    if (!_purchaseForm.currentState!
                                        .validate()) {
                                      return;
                                    }
                                    final order = await billing.buyCredits(
                                      tin,
                                      method: _method,
                                      phone: _phone.text.trim(),
                                      email: _email.text.trim(),
                                    );
                                    if (order != null && mounted) {
                                      setState(() => _prepared[tin] = order);
                                    }
                                  },
                            icon: const Icon(Icons.add_card),
                            label: const Text('Buy 500 credits — US\$5.00'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your balance updates automatically after payment confirmation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isTest)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test fiscalisation (demo)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This demo starts with 20 simulated credits. It sends nothing to ZIMRA and does not change your business wallet.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_demo?['available'] ?? 20} demo credits · ${_demo?['used'] ?? 0} documents',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (_demo?['replay'] == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Retry confirmed: no additional credit deducted.',
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _runDemo(tin, billing),
                                child: const Text('Run test with 20 credits'),
                              ),
                              if (_demoReceipt != null)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _runDemo(
                                          tin,
                                          billing,
                                          replay: true,
                                        ),
                                  child: const Text('Retry same document'),
                                ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        _demoRun = const Uuid().v4();
                                        _demoReceipt = null;
                                        _demo = null;
                                      }),
                                child: const Text('Reset demo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your verified purchases and pending payments will appear here.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final payment in payments) _payment(payment, tin, billing),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('About fiscalisation credits'),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: const [
                      Text(
                        'One credit per successfully fiscalised document in the connected environment. Test and production balances are separate. Retries and reprints do not cost extra. Credits appear only after payment verification. Documents with Red validation errors are not charged.',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          billing.disconnect(tin);
                          setState(() => _prepared.remove(tin));
                        },
                  child: const Text('Disconnect business'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
