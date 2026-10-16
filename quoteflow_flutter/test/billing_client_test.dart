import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/screens/credits_screen.dart';
import 'package:quoteflow/services/billing/billing_http_common.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

Map<String, dynamic> _wallet(
  String tin, {
  int available = 20,
  String mode = 'test',
}) => {
  'businessTin': tin,
  'mode': mode,
  'deviceIds': [123],
  'available': available,
  'used': 0,
  'reserved': 0,
  'trialGranted': 20,
  'payments': <dynamic>[],
};

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('test wallets cannot open the production credit gateway', () async {
    final billing = BillingProvider(
      post: (path, body, {token}) async => _wallet('2000000001'),
    );
    addTearDown(billing.dispose);
    await billing.connect('2000000001', 'code');
    expect(
      () => billing.productionTransport(
        const ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST'),
        const ZimraCredentials(privateKeyPem: 'dummy', certificatePem: 'dummy'),
      ),
      throwsA(isA<ZimraException>()),
    );
  });

  test(
    'receipt balance refresh waits for an in-flight wallet operation instead of being dropped',
    () async {
      final topup = Completer<Map<String, dynamic>>();
      var available = 20;
      var balanceReads = 0;
      final billing = BillingProvider(
        post: (path, body, {token}) async {
          if (path.endsWith('/balance')) {
            balanceReads++;
            return _wallet('2000000001', available: available, mode: 'live');
          }
          if (path.endsWith('/topups')) return topup.future;
          available = 19;
          return {'statusCode': 200, 'rawBody': '{"receiptID":42}'};
        },
      );
      addTearDown(billing.dispose);
      await billing.connect('2000000001', 'code');
      final transport = billing.productionTransport(
        const ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST'),
        const ZimraCredentials(privateKeyPem: 'dummy', certificatePem: 'dummy'),
      );
      final purchase = billing.buyCredits('2000000001');
      final reply = await transport.post(
        '/Device/v1/123/SubmitReceipt',
        body: {},
      );
      expect(reply.statusCode, 200);
      expect(balanceReads, 1);
      topup.complete({'reference': 'pending', 'status': 'Pending'});
      await purchase;
      await Future<void>.delayed(Duration.zero);
      expect(balanceReads, 2);
      expect(billing.wallet('2000000001')!['available'], 19);
    },
  );

  test(
    'connected test wallet uses the test gateway and refreshes accepted and uncertain receipts',
    () async {
      var available = 20;
      var uncertain = false;
      var sent = 0;
      final billing = BillingProvider(
        post: (path, body, {token}) async {
          if (path.endsWith('/balance'))
            return _wallet('2000000001', available: available);
          expect(path, '/api/zimra/test');
          expect(body['baseUrl'], ZimraEnvironment.test.baseUrl);
          sent++;
          available--;
          return {
            'statusCode': uncertain ? 503 : 200,
            'rawBody': uncertain ? '{}' : '{"receiptID":42}',
            if (uncertain) 'uncertain': true,
          };
        },
      );
      addTearDown(billing.dispose);
      const identity = ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST');
      const credentials = ZimraCredentials(
        privateKeyPem: 'dummy',
        certificatePem: 'dummy',
      );
      expect(billing.testTransport(identity, credentials), isNull);
      await billing.connect('2000000001', 'code');
      expect(
        () => billing.testTransport(
          const ZimraDeviceIdentity(deviceId: 999, serialNumber: 'OTHER'),
          credentials,
        ),
        throwsA(isA<ZimraException>()),
      );
      final transport = billing.testTransport(identity, credentials)!;
      final response = await transport.post(
        '/Device/v1/123/SubmitReceipt',
        body: {},
      );
      expect(response.statusCode, 200);
      await Future<void>.delayed(Duration.zero);
      expect(billing.wallet('2000000001')!['available'], 19);
      uncertain = true;
      await expectLater(
        transport.post('/Device/v1/123/SubmitReceipt', body: {}),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(billing.wallet('2000000001')!['available'], 18);
      expect(sent, 2);
      billing.disconnect('2000000001');
      expect(
        (await transport.post(
          '/Device/v1/123/SubmitReceipt',
          body: {},
        )).statusCode,
        401,
      );
      expect(sent, 2);
    },
  );

  test('deduction demo never replaces the business wallet', () async {
    final billing = BillingProvider(
      post: (path, body, {token}) async => path.endsWith('/balance')
          ? _wallet('2000000001')
          : {'mode': 'simulation', 'available': 19, 'used': 1, 'replay': false},
    );
    addTearDown(billing.dispose);
    await billing.connect('2000000001', 'code');
    final demo = await billing.simulateDeduction(
      '2000000001',
      'run',
      'receipt',
    );
    expect(demo!['available'], 19);
    expect(billing.wallet('2000000001')!['available'], 20);
  });
  test(
    'unverified or wrong-business responses cannot create a credit session',
    () async {
      final billing = BillingProvider(
        post: (path, body, {token}) async => _wallet('different'),
      );
      addTearDown(billing.dispose);
      expect(await billing.connect('2000000001', 'code'), isFalse);
      expect(billing.wallet('2000000001'), isNull);
      expect(billing.error('2000000001'), contains('could not be verified'));
    },
  );

  test(
    'business sessions are separate and lost top-up responses reuse the request ID',
    () async {
      final requests = <Map<String, dynamic>>[];
      final billing = BillingProvider(
        post: (path, body, {token}) async {
          if (path.endsWith('/balance'))
            return _wallet(body['businessTin'] as String);
          requests.add({...body});
          if (requests.length == 1)
            throw const SocketException('lost response');
          return {'reference': 'order', 'status': 'Pending'};
        },
      );
      addTearDown(billing.dispose);
      await billing.connect('2000000001', 'code-one');
      expect(billing.wallet('2000000002'), isNull);
      await billing.connect('2000000002', 'code-two');
      expect(await billing.buyCredits('2000000001'), isNull);
      await billing.buyCredits('2000000001');
      expect(requests[0]['requestId'], requests[1]['requestId']);
      expect(billing.wallet('2000000001')!['available'], 20);
      billing.disconnect('2000000001');
      expect(billing.wallet('2000000001'), isNull);
      expect(billing.wallet('2000000002'), isNotNull);
    },
  );

  test(
    'production gateway requires a bound device and propagates credit rejection without queueing',
    () async {
      final requests = <Map<String, dynamic>>[];
      final billing = BillingProvider(
        post: (path, body, {token}) async {
          if (path.endsWith('/balance'))
            return _wallet(body['businessTin'] as String, mode: 'live');
          requests.add(body);
          throw const BillingClientException(
            402,
            'No fiscalisation credits available.',
          );
        },
      );
      addTearDown(billing.dispose);
      const identity = ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST');
      const credentials = ZimraCredentials(
        privateKeyPem: 'dummy',
        certificatePem: 'dummy',
      );
      expect(
        () => billing.productionTransport(identity, credentials),
        throwsA(isA<ZimraException>()),
      );
      await billing.connect('2000000001', 'code');
      final transport = billing.productionTransport(identity, credentials);
      final reply = await transport.post(
        '/Device/v1/123/SubmitReceipt',
        body: {},
      );
      expect(reply.statusCode, 402);
      expect(requests.single['businessTin'], '2000000001');
      expect(requests.single['baseUrl'], ZimraEnvironment.production.baseUrl);
      expect(
        () => billing.productionTransport(
          const ZimraDeviceIdentity(deviceId: 999, serialNumber: 'OTHER'),
          credentials,
        ),
        throwsA(isA<ZimraException>()),
      );
    },
  );

  test(
    'ambiguous gateway results raise a network-style failure for signed receipt recovery',
    () async {
      final billing = BillingProvider(
        post: (path, body, {token}) async => path.endsWith('/balance')
            ? _wallet(body['businessTin'] as String, mode: 'live')
            : {'uncertain': true, 'statusCode': 503, 'rawBody': '{}'},
      );
      addTearDown(billing.dispose);
      await billing.connect('2000000001', 'code');
      final transport = billing.productionTransport(
        const ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST'),
        const ZimraCredentials(privateKeyPem: 'dummy', certificatePem: 'dummy'),
      );
      await expectLater(
        transport.post('/Device/v1/123/SubmitReceipt', body: {}),
        throwsA(isNot(isA<ZimraException>())),
      );
    },
  );

  for (final automatic in [false, true]) {
    testWidgets(
      'credits screen verifies payment ${automatic ? 'automatically' : 'manually'} without adding unverified credits',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final screenshotKey = GlobalKey();
        late Directory directory;
        final storage = StorageService();
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('billing-ui-');
          PathProviderPlatform.instance = _Paths(directory.path);
          await storage.init();
          await storage.saveActiveOrg(
            Organization(id: 'org', name: 'Test Business', tin: '2000000001'),
          );
        });
        var available = 20;
        final billing = BillingProvider(
          post: (path, body, {token}) async {
            if (path.endsWith('/balance'))
              return _wallet(
                body['businessTin'] as String,
                available: available,
              );
            if (path.endsWith('/payment')) {
              available = 520;
              return {'status': 'Paid'};
            }
            return {
              'reference': 'test-reference',
              'status': 'Pending',
              'checkoutUrl':
                  'https://www.paynow.co.zw/Payment/ConfirmPayment/test',
            };
          },
        );
        final organizations = OrganizationProvider(storage);
        addTearDown(() async {
          billing.dispose();
          organizations.dispose();
          await storage.close();
          await directory.delete(recursive: true);
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: billing),
              ChangeNotifierProvider.value(value: organizations),
            ],
            child: RepaintBoundary(
              key: screenshotKey,
              child: const MaterialApp(home: CreditsScreen()),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'business-access-code');
        await tester.tap(find.text('Connect business'));
        await tester.pumpAndSettle();
        expect(find.text('20'), findsOneWidget);
        expect(find.text('Available credits'), findsOneWidget);
        expect(
          find.textContaining('Accepted ZIMRA test documents'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Bank / card'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Bank / card')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bank / card'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Buy 500 credits — US\$5.00'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buy 500 credits — US\$5.00'));
        await tester.pumpAndSettle();
        expect(billing.wallet('2000000001')!['available'], 20);
        await tester.scrollUntilVisible(
          find.text('Open Paynow'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Open Paynow'), findsOneWidget);
        if (automatic) {
          await tester.pump(const Duration(seconds: 8));
          await tester.pumpAndSettle();
        } else {
          await tester.scrollUntilVisible(
            find.text("Check payment status"),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text("Check payment status"));
          await tester.pumpAndSettle();
        }
        expect(billing.wallet('2000000001')!['available'], 520);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
