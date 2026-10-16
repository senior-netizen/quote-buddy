import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/screens/clients/client_list_screen.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/widgets/customer_form.dart';
import 'package:quoteflow/widgets/document_form_screen.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late StorageService storage;
  late ClientProvider customers;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('customer-form');
    PathProviderPlatform.instance = _Paths(dir.path);
    storage = StorageService();
    await storage.init();
    customers = ClientProvider(storage);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: customers),
      ChangeNotifierProvider(create: (_) => DocumentProvider(storage)),
      ChangeNotifierProvider(create: (_) => OrganizationProvider(storage)),
    ],
    child: MaterialApp(home: home),
  );

  for (final fromInvoice in [false, true]) {
    testWidgets(
      '${fromInvoice ? "Document" : "Customer list"} uses shared form and permits name-only customer',
      (tester) async {
        await tester.pumpWidget(
          app(
            fromInvoice ? const DocumentFormScreen() : const ClientListScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (fromInvoice) {
          await tester.tap(find.byTooltip('Add client'));
        } else {
          await tester.tap(find.text('New'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(CustomerForm), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Display / Customer Name *'),
          'Jane Customer',
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Save Customer'));
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (customers.allClients.isEmpty &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        await tester.pumpAndSettle();
        expect(customers.allClients.single.companyName, 'Jane Customer');
        expect(customers.allClients.single.tin, isNull);
        expect(customers.allClients.single.vatRegistered, false);
        if (fromInvoice) expect(find.text('Jane Customer'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
