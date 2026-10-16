import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/screens/settings/fdms_readiness_screen.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/services/zimra/zimra.dart';
import 'package:quoteflow/theme/app_theme.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dark in [false, true]) {
    testWidgets(
      'approval readiness stays incomplete at 320px with large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = StorageService();
        late Directory temp;
        late Box box;
        await tester.runAsync(() async {
          temp = await Directory.systemTemp.createTemp('readiness-ui-');
          PathProviderPlatform.instance = _Paths(temp.path);
          await storage.init();
          await storage.saveActiveOrg(
            Organization(id: 'org', name: 'Example Ltd', tin: '2000000001'),
          );
          box = await Hive.openBox('approval-ui');
          await box.putAll({
            'zimra_identity': const ZimraDeviceIdentity(
              deviceId: 123,
              serialNumber: 'TEST',
            ).toJson(),
            'zimra_credentials': const ZimraCredentials(
              privateKeyPem: 'not-exported',
              certificatePem: 'certificate',
            ).toJson(),
          });
        });
        final zimra = ZimraProvider(box);
        await tester.runAsync(zimra.init);
        final orgs = OrganizationProvider(storage);
        addTearDown(() async {
          zimra.dispose();
          orgs.dispose();
          await box.close();
          await storage.close();
          await temp.delete(recursive: true);
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: zimra),
              ChangeNotifierProvider.value(value: orgs),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const FdmsReadinessScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('not ZIMRA approval'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Export submission evidence + sample PDFs'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final button = tester.widget<FilledButton>(
          find
              .ancestor(
                of: find.text('Export submission evidence + sample PDFs'),
                matching: find.byType(FilledButton),
              )
              .first,
        );
        expect(button.onPressed, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
