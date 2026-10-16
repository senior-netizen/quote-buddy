import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quoteflow/models/organization.dart';
import 'package:quoteflow/providers/billing_provider.dart';
import 'package:quoteflow/providers/business_account_provider.dart';
import 'package:quoteflow/providers/organization_provider.dart';
import 'package:quoteflow/screens/business_account_screen.dart';
import 'package:quoteflow/services/billing/billing_http_common.dart';
import 'package:quoteflow/services/onboarding/session_store.dart';
import 'package:quoteflow/services/storage.dart';
import 'package:quoteflow/theme/app_theme.dart';

class _MemoryStore implements AccountSessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

Map<String, dynamic> _tokens({bool verified = false}) => {
  'accessToken': 'qfa_${'a' * 64}',
  'refreshToken': 'qfr_${'b' * 64}',
  'expiresIn': 1800,
  'account': {
    'id': 'account-a',
    'email': 'owner@example.com',
    'verified': verified,
  },
  'emailSent': true,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'registration stores only the refresh token and email confirmation is separate from approval',
    () async {
      final store = _MemoryStore();
      var verified = false;
      final provider = BusinessAccountProvider(
        store: store,
        post: (path, body, {token}) async {
          if (body['action'] == 'register') return _tokens();
          if (body['action'] == 'verify-email') {
            verified = true;
            return {'verified': true};
          }
          return {
            'account': _tokens(verified: verified)['account'],
            'mode': 'test',
            'applications': [],
          };
        },
      );
      addTearDown(provider.dispose);
      expect(
        await provider.signIn(
          'owner@example.com',
          'A long private password 123!',
          register: true,
        ),
        true,
      );
      expect(store.value, 'qfr_${'b' * 64}');
      expect(provider.emailVerified, false);
      expect(provider.applications, isEmpty);
      expect(await provider.verify('123456'), true);
      expect(provider.emailVerified, true);
      expect(provider.applications, isEmpty);
    },
  );
  test(
    'native restoration rotates credentials and restores approved wallets automatically',
    () async {
      final store = _MemoryStore()..value = 'qfr_old';
      var refreshed = false;
      final provider = BusinessAccountProvider(
        store: store,
        post: (path, body, {token}) async {
          if (path.endsWith('/balance'))
            return {
              'businessTin': '2000000002',
              'mode': 'test',
              'available': 20,
              'deviceIds': [777],
              'payments': [],
            };
          if (body['action'] == 'refresh') {
            expect(body['refreshToken'], 'qfr_old');
            refreshed = true;
            return _tokens(verified: true);
          }
          return {
            'account': _tokens(verified: true)['account'],
            'mode': 'test',
            'applications': [
              {'id': 'app-a', 'tin': '2000000002', 'state': 'approved'},
            ],
          };
        },
      );
      final billing = BillingProvider(post: provider.billingPostWithAccount);
      provider.billing = billing;
      addTearDown(provider.dispose);
      addTearDown(billing.dispose);
      await provider.restore();
      expect(refreshed, true);
      expect(provider.signedIn, true);
      expect(store.value, 'qfr_${'b' * 64}');
      expect(billing.wallet('2000000002')!['available'], 20);
      await provider.signOut();
      expect(store.value, isNull);
      expect(billing.wallet('2000000002'), isNull);
    },
  );
  test(
    'offline restoration preserves the secure refresh token for a later retry',
    () async {
      final store = _MemoryStore()..value = 'qfr_offline';
      final provider = BusinessAccountProvider(
        store: store,
        post: (path, body, {token}) async =>
            throw const SocketException('offline'),
      );
      addTearDown(provider.dispose);
      await provider.restore();
      expect(provider.signedIn, false);
      expect(store.value, 'qfr_offline');
      expect(provider.restoring, false);
    },
  );
  test('a late sign-in cannot reconnect an account after sign-out', () async {
    final response = Completer<Map<String, dynamic>>();
    final store = _MemoryStore();
    final provider = BusinessAccountProvider(
      store: store,
      post: (path, body, {token}) async {
        if (body['action'] == 'logout') return {'signedOut': true};
        return response.future;
      },
    );
    addTearDown(provider.dispose);
    final signingIn = provider.signIn(
      'owner@example.com',
      'A long private password 123!',
    );
    await provider.signOut();
    response.complete(_tokens());
    await signingIn;
    expect(provider.signedIn, false);
    expect(store.value, isNull);
  });
  test('pending applications cannot connect a wallet', () async {
    final provider = BusinessAccountProvider(
      store: _MemoryStore(),
      post: (path, body, {token}) async {
        if (body['action'] == 'login') return _tokens(verified: true);
        return {
          'account': _tokens(verified: true)['account'],
          'mode': 'test',
          'applications': [
            {'tin': '2000000002', 'state': 'pending'},
          ],
        };
      },
    );
    addTearDown(provider.dispose);
    await provider.signIn('owner@example.com', 'A long private password 123!');
    expect(await provider.connectWallet('2000000002'), false);
    expect(provider.error, contains('approved access'));
  });
  for (final dark in [false, true]) {
    testWidgets(
      'onboarding renders at 320px with large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Directory directory;
        late StorageService storage;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('onboarding-ui');
          PathProviderPlatform.instance = _Paths(directory.path);
          storage = StorageService();
          await storage.init();
          await storage.saveActiveOrg(
            Organization(id: 'org', name: 'Acacia Trading', tin: '2000000002'),
          );
        });
        final org = OrganizationProvider(storage);
        final store = _MemoryStore();
        final provider = BusinessAccountProvider(
          store: store,
          post: (path, body, {token}) async {
            if (body['action'] == 'register') return _tokens();
            return {
              'account': _tokens()['account'],
              'mode': 'test',
              'applications': [],
            };
          },
        );
        addTearDown(() async {
          provider.dispose();
          org.dispose();
          await storage.close();
          await directory.delete(recursive: true);
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: org),
              ChangeNotifierProvider.value(value: provider),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.4)),
                child: child!,
              ),
              home: const BusinessAccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create your business account'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email address'),
          'owner@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'A long private password 123!',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text('Create account')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(find.text('Verify email'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('application states render safely with large text in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory directory;
    late StorageService storage;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('onboarding-states');
      PathProviderPlatform.instance = _Paths(directory.path);
      storage = StorageService();
      await storage.init();
      await storage.saveActiveOrg(
        Organization(id: 'org', name: 'Acacia Trading', tin: '2000000002'),
      );
    });
    final org = OrganizationProvider(storage);
    addTearDown(() async {
      org.dispose();
      await storage.close();
      await directory.delete(recursive: true);
    });
    for (final state in [
      'pending',
      'changes_requested',
      'rejected',
      'approved',
    ]) {
      final account = BusinessAccountProvider(
        store: _MemoryStore(),
        post: (path, body, {token}) async =>
            throw StateError('No live service in rendering check'),
      );
      account.account =
          _tokens(verified: true)['account'] as Map<String, dynamic>;
      account.applications = [
        {
          'id': 'app-a',
          'tin': '2000000002',
          'business_name': 'Acacia Trading',
          'state': state,
          'device_ids': [777],
          'files': [],
          'profile': {
            'contactName': 'Jane Owner',
            'phone': '0771234567',
            'address': 'Harare',
          },
          'evidence': 'Signed ownership declaration',
          'public_message': state == 'changes_requested'
              ? 'Please add device ownership evidence.'
              : '',
        },
      ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: org),
            ChangeNotifierProvider.value(value: account),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!,
            ),
            home: const BusinessAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: state);
      await tester.pumpWidget(const SizedBox.shrink());
      account.dispose();
    }
  });
}
