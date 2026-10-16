import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quoteflow/models/document.dart';
import 'package:quoteflow/models/product.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/providers/business_account_provider.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/providers/product_provider.dart';
import 'package:quoteflow/providers/settings_provider.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/screens/app_shell.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/theme/app_theme.dart';
import 'package:quoteflow/widgets/reference_design.dart';

class _ReferencePaths extends PathProviderPlatform {
  final String path;
  _ReferencePaths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'reference shell retains navigation and business actions at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        final storage = StorageService();
        late OrganizationProvider organizations;
        late ClientProvider clients;
        late DocumentProvider documents;
        late ProductProvider products;
        late AppSettingsProvider settings;
        late ZimraProvider zimra;
        final billing = BillingProvider(
          post: (path, body, {token}) async => throw StateError(
            'This navigation check must never contact the billing server.',
          ),
        );
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp(
            'reference-navigation-',
          );
          PathProviderPlatform.instance = _ReferencePaths(directory.path);
          SharedPreferences.setMockInitialValues({});
          await storage.init();
          organizations = OrganizationProvider(storage);
          clients = ClientProvider(storage);
          documents = DocumentProvider(storage);
          products = ProductProvider(storage);
          settings = AppSettingsProvider();
          await settings.init();
          zimra = ZimraProvider(await Hive.openBox('reference-ui'));
          await zimra.init();
          final client = await clients.createClient(
            companyName: 'Example customer',
          );
          await documents.createDocument(
            type: DocumentType.invoice,
            docNumber: 'INV-2026-0001',
            issueDate: '2026-10-14',
            clientId: client.id,
            lineItems: [
              LineItem(description: 'Service', quantity: 1, unitPrice: 35000),
            ],
            taxRate: 0,
            discount: 0,
            status: 'draft',
          );
          await products.save(
            Product(
              id: 'product',
              orgId: organizations.activeOrgId,
              name: 'PLC programming',
              price: 35000,
              quantity: 5,
            ),
          );
        });
        final account = BusinessAccountProvider(
          post: (path, body, {token}) async =>
              throw StateError('Navigation must remain offline'),
        );
        addTearDown(account.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider.value(value: storage),
              ChangeNotifierProvider.value(value: organizations),
              ChangeNotifierProvider.value(value: clients),
              ChangeNotifierProvider.value(value: documents),
              ChangeNotifierProvider.value(value: products),
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: zimra),
              ChangeNotifierProvider.value(value: billing),
              ChangeNotifierProvider.value(value: account),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => ReferenceBackdrop(child: child!),
              home: const AppShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Good to see you.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final navigation = find.byType(NavigationBar);
        for (final name in [
          'Documents',
          'Clients',
          'Inventory',
          'Settings',
          'Overview',
        ]) {
          await tester.tap(
            find.descendant(of: navigation, matching: find.text(name)),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$name must render without overflow',
          );
        }
        await tester.tap(find.byTooltip('Business activity and credits'));
        await tester.pumpAndSettle();
        expect(find.text('Fiscalisation credits'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          billing.dispose();
          zimra.dispose();
          settings.dispose();
          products.dispose();
          documents.dispose();
          clients.dispose();
          organizations.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        });
      },
    );
  }
}
