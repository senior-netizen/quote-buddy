import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/product.dart';
import 'package:quoteflow/providers/product_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/providers/client_provider.dart';
import 'package:quoteflow/providers/document_provider.dart';
import 'package:quoteflow/screens/products_screen.dart';
import 'package:quoteflow/services/backup_service.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/widgets/document_form_screen.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  late ProductProvider products;
  late OrganizationProvider orgs;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-test-');
    PathProviderPlatform.instance = _Paths(directory.path);
    storage = StorageService();
    await storage.init();
    products = ProductProvider(storage);
    orgs = OrganizationProvider(storage);
  });
  tearDown(() async {
    products.dispose();
    orgs.dispose();
    await storage.close();
    await directory.delete(recursive: true);
  });
  Product pen({
    String id = 'pen',
    String? orgId,
    String sku = 'PEN-01',
    double quantity = 12,
  }) => Product(
    id: id,
    orgId: orgId ?? orgs.activeOrgId,
    name: 'Blue pen',
    sku: sku,
    category: 'Stationery',
    price: 1.65,
    quantity: quantity,
  );
  Widget app(Widget screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: products),
      ChangeNotifierProvider.value(value: orgs),
      ChangeNotifierProvider(create: (_) => ClientProvider(storage)),
      ChangeNotifierProvider(create: (_) => DocumentProvider(storage)),
    ],
    child: MaterialApp(home: screen),
  );

  test(
    'search, SKU uniqueness, stock filtering and organization isolation',
    () async {
      final firstOrg = orgs.activeOrgId;
      await products.save(pen());
      await products.save(pen(id: 'empty', sku: 'EMPTY', quantity: 0));
      final secondOrg = await orgs.createOrganization('Other business');
      await products.save(pen(id: 'other', orgId: secondOrg.id));
      expect(products.search(firstOrg, 'stationery PEN-01').single.id, 'pen');
      expect(products.search(firstOrg, 'BLUE').length, 2);
      expect(products.search(firstOrg, '', inStockOnly: true).single.id, 'pen');
      expect(products.search(secondOrg.id, '').single.id, 'other');
      await expectLater(
        products.save(pen(id: 'duplicate', orgId: firstOrg, sku: 'pen-01')),
        throwsArgumentError,
      );
      await expectLater(
        products.save(pen(id: 'pen', orgId: secondOrg.id)),
        throwsArgumentError,
      );
      await expectLater(
        products.save(pen(id: 'negative', quantity: -1)),
        throwsArgumentError,
      );
    },
  );

  test(
    'products survive restart and backup restoration including older backups',
    () async {
      await products.save(pen());
      final backup = BackupService(storage);
      final json = backup.exportJson();
      await storage.close();
      await storage.init();
      expect(storage.getProduct('pen')!.quantity, 12);
      await products.delete(storage.getProduct('pen')!);
      final result = await backup.importFromJson(json);
      expect(result.success, isTrue);
      expect(result.productsImported, 1);
      expect(storage.getProduct('pen')!.price, 1.65);
      expect(
        (await backup.importFromJson('{"documents":[],"clients":[]}')).success,
        isTrue,
      );
      expect(storage.getProduct('pen'), isNotNull);
    },
  );

  test(
    'optional product photos survive backup restoration and invalid image data is rejected',
    () async {
      const image =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF5UAAAAASUVORK5CYII=';
      final photo = Product(
        id: 'photo',
        orgId: orgs.activeOrgId,
        name: 'Photo product',
        price: 1,
        quantity: 2,
        imageDataUrl: image,
      );
      await products.save(photo);
      final backup = BackupService(storage),
          json = BackupService(storage).exportJson();
      await products.delete(photo);
      expect((await backup.importFromJson(json)).success, isTrue);
      expect(storage.getProduct('photo')!.imageDataUrl, image);
      expect(
        () => Product(
          id: 'invalid',
          orgId: orgs.activeOrgId,
          name: 'Invalid photo',
          price: 1,
          quantity: 1,
          imageDataUrl: 'https://example.com/image.png',
        ).validate(),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'inventory searches products and updates when organization changes',
    (tester) async {
      final firstOrg = orgs.activeOrgId;
      late String secondOrgId;
      await tester.runAsync(() async {
        await products.save(pen());
        final secondOrg = await orgs.createOrganization('Other business');
        secondOrgId = secondOrg.id;
        await products.save(
          Product(
            id: 'other',
            orgId: secondOrg.id,
            name: 'Hammer',
            price: 9,
            quantity: 0,
          ),
        );
        await storage.switchOrg(firstOrg);
      });
      await tester.pumpWidget(app(const ProductsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Blue pen'), findsOneWidget);
      expect(find.text('Hammer'), findsNothing);
      await tester.enterText(find.byType(TextField), 'not found');
      await tester.pump();
      expect(find.text('No matching products'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'PEN-01');
      await tester.pump();
      expect(find.text('Blue pen'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.runAsync(() async {
        await storage.switchOrg(secondOrgId);
        orgs.switchOrganization(secondOrgId);
      });
      await tester.pumpAndSettle();
      expect(find.text('Hammer'), findsOneWidget);
      expect(find.text('Blue pen'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'In stock'));
      await tester.pump();
      expect(find.text('No matching products'), findsOneWidget);
    },
  );

  testWidgets(
    'product picker copies price into a document without changing stock',
    (tester) async {
      await tester.runAsync(() => products.save(pen()));
      await tester.pumpWidget(app(const DocumentFormScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add from inventory'));
      await tester.tap(find.text('Add from inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue pen'));
      await tester.pumpAndSettle();
      final values = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((w) => w.controller?.text)
          .toList();
      expect(values, contains('Blue pen'));
      expect(values, contains('1.65'));
      expect(storage.getProduct('pen')!.quantity, 12);
      expect(tester.takeException(), isNull);
    },
  );
}
