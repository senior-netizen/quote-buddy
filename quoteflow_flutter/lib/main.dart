import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'services/storage.dart';
import 'providers/document_provider.dart';
import 'providers/client_provider.dart';
import 'providers/product_provider.dart';
import 'providers/organization_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/zimra_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/business_account_provider.dart';
import 'screens/app_shell.dart';
import 'screens/launch_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/reference_design.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuoteFlowBootstrap());
}

class QuoteFlowBootstrap extends StatefulWidget {
  const QuoteFlowBootstrap({super.key});
  @override
  State<QuoteFlowBootstrap> createState() => _QuoteFlowBootstrapState();
}

class _QuoteFlowBootstrapState extends State<QuoteFlowBootstrap> {
  late Future<Widget> _application = _initializeApplication();
  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _application,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: QuoteFlowLaunchScreen(
          retry: snapshot.hasError
              ? () => setState(() => _application = _initializeApplication())
              : null,
        ),
      );
    },
  );
}

Future<Widget> _initializeApplication() async {
  final storage = StorageService();
  await storage.init();

  final settings = AppSettingsProvider();
  await settings.init();

  // Open ZIMRA hive box and init provider
  final zimraBox = await Hive.openBox('zimra');
  final account = BusinessAccountProvider();
  final billing = BillingProvider(post: account.billingPostWithAccount);
  account.billing = billing;
  unawaited(account.restore());
  final zimraProvider = ZimraProvider(
    zimraBox,
    productionTransportFactory: billing.productionTransport,
    testTransportFactory: billing.testTransport,
  );
  await zimraProvider.init();

  return MultiProvider(
    providers: [
      Provider.value(value: storage),
      ChangeNotifierProvider(create: (_) => settings),
      ChangeNotifierProvider(create: (_) => OrganizationProvider(storage)),
      ChangeNotifierProvider(create: (_) => ClientProvider(storage)),
      ChangeNotifierProvider(create: (_) => ProductProvider(storage)),
      ChangeNotifierProvider(create: (_) => DocumentProvider(storage)),
      ChangeNotifierProvider.value(value: zimraProvider),
      ChangeNotifierProvider.value(value: billing),
      ChangeNotifierProvider.value(value: account),
    ],
    child: const QuoteflowApp(),
  );
}

class QuoteflowApp extends StatelessWidget {
  const QuoteflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return MaterialApp(
      title: 'QuoteFlow',
      debugShowCheckedModeBanner: false,
      // The lock gate wraps the Navigator so a protected app shows the PIN
      // screen over every route — including pushed screens — and re-locks
      // whenever QuoteFlow returns from the background.
      builder: (context, child) => ReferenceBackdrop(
        child: LockGate(child: child ?? const SizedBox.shrink()),
      ),
      themeMode: settings.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const OfflineBanner(child: AppShell()),
    );
  }
}

/// Banner shown when the app is running offline.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _syncConnectivity();
    // React to connectivity changes while the app is open.
    _subscription = Connectivity().onConnectivityChanged.listen(
      _applyConnectivity,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _syncConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _applyConnectivity(results);
    } catch (_) {
      // If the platform can't report connectivity, assume we're online.
      _applyConnectivity(const [ConnectivityResult.wifi]);
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    setState(() => _isOffline = offline);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_isOffline)
          Material(
            color: scheme.surface,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline — all data is saved locally',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
