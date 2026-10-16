import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import '../server/billing/ledger.dart';
import '../server/billing/paynow.dart';
import '../server/billing/routes.dart';
import '../server/billing/service.dart';

const _key = 'public-dummy-test-key';
const _pollUrl = 'https://www.paynow.co.zw/Interface/CheckPayment/?guid=test';
const _business = VerifiedBusiness('2000000001', '', [123]);

class _Paynow implements PaynowGateway {
  Map<String, String> fields = {};
  String status = 'Paid';
  String amount = '5.00';
  int initiations = 0;
  int polls = 0;
  bool failInitiation = false;
  @override
  Map<String, String> decode(String raw) => decodePaynow(raw, _key);
  @override
  Future<Map<String, String>> initiate(Map<String, String> values) async {
    initiations++;
    fields = values;
    if (failInitiation) throw const SocketException('connection lost');
    return {
      'status': 'Ok',
      'browserurl': 'https://www.paynow.co.zw/Payment/ConfirmPayment/test',
      'pollurl': _pollUrl,
    };
  }

  Map<String, String> message() => {
    'reference': fields['reference']!,
    'amount': amount,
    'paynowreference': 'PN-123',
    'pollurl': _pollUrl,
    'status': status,
  };
  String notification({Map<String, String>? values}) {
    final data = values ?? message();
    return {...data, 'hash': paynowHash(data, _key)}.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
  }

  @override
  Future<Map<String, String>> poll(String url) async {
    polls++;
    return message();
  }
}

Map<String, dynamic> _receipt(
  int number, {
  String hash = 'hash',
  String signature = 'signature',
}) => {
  'receipt': {
    'receiptGlobalNo': number,
    'receiptTotal': 5,
    'receiptDeviceSignature': {'hash': '$hash-$number', 'signature': signature},
  },
};

void main() {
  late Directory directory;
  late Box box;
  late CreditLedger ledger;
  late _Paynow paynow;
  late BillingService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('billing-ledger-');
    Hive.init(directory.path);
    box = await Hive.openBox('ledger');
    ledger = CreditLedger(box);
    paynow = _Paynow();
    service = BillingService(
      ledger: ledger,
      paynow: paynow,
      publicBaseUrl: Uri.parse('https://billing.example'),
      businesses: [_business],
      live: true,
    );
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('a late paid status cannot restore refunded credits', () async {
    await ledger.payment(
      _business.tin,
      'audit-order',
      'audit-provider-ref',
      'Paid',
    );
    await ledger.payment(
      _business.tin,
      'audit-order',
      'audit-provider-ref',
      'Refunded',
    );
    await ledger.payment(
      _business.tin,
      'audit-order',
      'audit-provider-ref',
      'Paid',
    );
    expect(ledger.totals(_business.tin)['purchased'], 0);
  });

  test('a reversal before the first paid status remains final', () async {
    await ledger.payment(
      _business.tin,
      'audit-order',
      'audit-provider-ref',
      'Cancelled',
    );
    await ledger.payment(
      _business.tin,
      'audit-order',
      'audit-provider-ref',
      'Paid',
    );
    expect(ledger.totals(_business.tin)['purchased'], 0);
  });

  test('verified late paid status cannot overwrite a final refund', () async {
    final order = await service.createTopup(
      _business,
      'audit-late-status-order',
    );
    await service.notification(paynow.notification());
    paynow.status = 'Refunded';
    await service.notification(paynow.notification());
    paynow.status = 'Paid';
    await service.notification(paynow.notification());
    expect(
      service.paymentStatus(_business, order['reference'] as String)['status'],
      'Refunded',
    );
    expect(ledger.totals(_business.tin)['purchased'], 0);
  });

  test('EcoCash initiates a phone prompt without a browser checkout', () async {
    final result = await service.createTopup(
      _business,
      'mobile-payment-request-01',
      method: 'ecocash',
      phone: '+263 77 123 4567',
      email: 'payer@example.com',
    );
    expect(paynow.fields['method'], 'ecocash');
    expect(paynow.fields['phone'], '0771234567');
    expect(paynow.fields['authemail'], 'payer@example.com');
    expect(result['method'], 'ecocash');
    expect(result['checkoutUrl'], isNull);
    expect(result['status'], 'Pending');
  });

  test('invalid mobile details never initiate a payment', () async {
    await expectLater(
      service.createTopup(
        _business,
        'mobile-payment-request-02',
        method: 'ecocash',
        phone: '123',
        email: 'payer@example.com',
      ),
      throwsA(isA<BillingError>()),
    );
    expect(paynow.initiations, 0);
  });

  test('Telecash uses hosted Paynow checkout', () async {
    final result = await service.createTopup(
      _business,
      'telecash-payment-request',
      method: 'telecash',
    );
    expect(result['method'], 'telecash');
    expect(result['checkoutUrl'], startsWith('https://www.paynow.co.zw/'));
    expect(paynow.fields.containsKey('method'), isFalse);
  });

  test('Paynow official SHA512 hash vector and tamper detection', () {
    const key = '3e9fed89-60e1-4ce5-ab6e-6b1eb2d4f977';
    final fields = {
      'id': '1201',
      'reference': 'TEST REF',
      'amount': '99.99',
      'additionalinfo': 'A test ticket transaction',
      'returnurl': 'http://www.google.com/search?q=returnurl',
      'resulturl': 'http://www.google.com/search?q=resulturl',
      'status': 'Message',
    };
    expect(
      paynowHash(fields, key),
      '2A033FC38798D913D42ECB786B9B19645ADEDBDE788862032F1BD82CF3B92DEF84F316385D5B40DBB35F1A4FD7D5BFE73835174136463CDD48C9366B0749C689',
    );
    paynow.fields = {'reference': 'a'};
    final raw = paynow.notification();
    expect(decodePaynow(raw, _key)['amount'], '5.00');
    expect(
      () => decodePaynow(raw.replaceFirst('5.00', '1.00'), _key),
      throwsA(isA<BillingError>()),
    );
    expect(
      () => decodePaynow('$raw&amount=5.00', _key),
      throwsA(isA<BillingError>()),
    );
    expect(
      () => trustedPaynowUrl('https://www.paynow.co.zw.evil.example/pay'),
      throwsA(isA<BillingError>()),
    );
    expect(
      () => trustedPaynowUrl('http://www.paynow.co.zw/pay'),
      throwsA(isA<BillingError>()),
    );
  });

  test(
    'verified business authentication is not based on a client-supplied TIN alone',
    () {
      final secured = BillingService(
        ledger: ledger,
        paynow: paynow,
        publicBaseUrl: Uri.parse('https://example.com'),
        businesses: [
          VerifiedBusiness(
            _business.tin,
            sha256.convert(utf8.encode('business-code')).toString(),
            [123],
          ),
        ],
      );
      expect(
        () => secured.authenticate(_business.tin, 'Bearer wrong'),
        throwsA(isA<BillingError>()),
      );
      expect(
        () => secured.authenticate('2000000002', 'Bearer business-code'),
        throwsA(isA<BillingError>()),
      );
      expect(
        secured.authenticate(_business.tin, 'Bearer business-code').deviceIds,
        [123],
      );
    },
  );

  test(
    'local sandbox identities are excluded when live mode is enabled',
    () async {
      final keyFile = File('${directory.path}/dummy.key');
      final configFile = File('${directory.path}/businesses.json');
      await keyFile.writeAsString(_key);
      await configFile.writeAsString(
        jsonEncode([
          {
            'tin': '0000000000',
            'verified': false,
            'testOnly': true,
            'deviceIds': [123],
            'tokenSha256': sha256.convert(utf8.encode('dummy-code')).toString(),
          },
        ]),
      );
      final env = {
        'PAYNOW_KEY_FILE': keyFile.path,
        'BILLING_BUSINESSES_FILE': configFile.path,
        'BILLING_DATA_DIR': directory.path,
        'BILLING_PUBLIC_URL': 'http://localhost:8087',
        'PAYNOW_MODE': 'test',
      };
      final sandbox = (await loadBilling(environment: env))!;
      expect(
        sandbox.authenticate('0000000000', 'Bearer dummy-code').tin,
        '0000000000',
      );
      await sandbox.ledger.box.close();
      final production = (await loadBilling(
        environment: {
          ...env,
          'PAYNOW_MODE': 'live',
          'BILLING_PUBLIC_URL': 'https://example.com',
        },
      ))!;
      expect(
        () => production.authenticate('0000000000', 'Bearer dummy-code'),
        throwsA(isA<BillingError>()),
      );
      await production.ledger.box.close();
    },
  );

  test(
    'trial survives reconnection, receipt consumption and server restart',
    () async {
      expect((await service.balance(_business))['available'], 20);
      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: () async => const FiscalReply(200, '{"receiptID":1}'),
      );
      expect((await service.balance(_business))['available'], 19);
      await box.close();
      box = await Hive.openBox('ledger');
      ledger = CreditLedger(box);
      await ledger.ensureTrial(_business.tin);
      expect(ledger.totals(_business.tin)['available'], 19);
    },
  );

  test(
    'payment retries and duplicate callbacks add 500 credits exactly once',
    () async {
      final first = await service.createTopup(_business, 'request-id-00000001');
      final retry = await service.createTopup(_business, 'request-id-00000001');
      final secondTap = await service.createTopup(
        _business,
        'request-id-00000002',
      );
      expect(first['reference'], retry['reference']);
      expect(first['reference'], secondTap['reference']);
      expect(paynow.initiations, 1);
      await Future.wait(
        List.generate(5, (_) => service.notification(paynow.notification())),
      );
      expect(ledger.totals(_business.tin)['available'], 520);
      expect(paynow.polls, 5);
      expect(
        service.paymentStatus(
          _business,
          first['reference'] as String,
        )['status'],
        'Paid',
      );
    },
  );

  test(
    'lost initiation response retains one order and never automatically charges again',
    () async {
      paynow.failInitiation = true;
      final order = await service.createTopup(_business, 'request-id-00000001');
      expect(order['status'], 'InitiationUnknown');
      await service.createTopup(_business, 'request-id-00000002');
      expect(paynow.initiations, 1);
      await service.notification(paynow.notification());
      expect(ledger.totals(_business.tin)['available'], 520);
    },
  );

  test(
    'a provider payment reference cannot fund two different orders or businesses',
    () async {
      await ledger.payment(
        _business.tin,
        'order-one',
        'unique-provider-payment',
        'Paid',
      );
      await expectLater(
        ledger.payment(
          _business.tin,
          'order-two',
          'unique-provider-payment',
          'Paid',
        ),
        throwsA(isA<BillingError>()),
      );
      await expectLater(
        ledger.payment(
          '2000000002',
          'order-three',
          'unique-provider-payment',
          'Paid',
        ),
        throwsA(isA<BillingError>()),
      );
      expect(ledger.totals(_business.tin)['available'], 520);
      expect(ledger.totals('2000000002')['available'], 20);
    },
  );

  test(
    'callback is not proof of payment; wrong amounts and unpaid polls do not grant credits',
    () async {
      await service.createTopup(_business, 'request-id-00000001');
      paynow.status = 'Created';
      await service.notification(paynow.notification());
      expect(ledger.totals(_business.tin)['available'], 20);
      paynow.amount = '0.05';
      await expectLater(
        service.notification(paynow.notification()),
        throwsA(isA<BillingError>()),
      );
      expect(ledger.totals(_business.tin)['available'], 20);
      paynow.amount = '5.00';
      final notification = paynow.notification();
      paynow.amount = '99.00';
      await expectLater(
        service.notification(notification),
        throwsA(isA<BillingError>()),
      );
      expect(ledger.totals(_business.tin)['available'], 20);
    },
  );

  test(
    'refunds reverse purchased credits without granting them again on duplicate notifications',
    () async {
      await service.createTopup(_business, 'request-id-00000001');
      await service.notification(paynow.notification());
      paynow.status = 'Refunded';
      await service.notification(paynow.notification());
      await service.notification(paynow.notification());
      expect(ledger.totals(_business.tin)['available'], 20);
    },
  );

  test(
    'successful receipt replay and a new ECDSA signature do not charge or submit twice',
    () async {
      var calls = 0;
      Future<FiscalReply> send() async {
        calls++;
        return const FiscalReply(200, '{"receiptID":1}');
      }

      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: send,
      );
      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1, signature: 'new signature'),
        send: send,
      );
      expect(calls, 1);
      expect(ledger.totals(_business.tin)['available'], 19);
      await expectLater(
        ledger.fiscalise(
          tin: _business.tin,
          deviceId: 123,
          payload: _receipt(1, hash: 'different'),
          send: send,
        ),
        throwsA(isA<BillingError>()),
      );
    },
  );

  test(
    'definite rejection costs nothing; red accepted response is free and cached',
    () async {
      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: () async => const FiscalReply(400, '{}'),
      );
      expect(ledger.totals(_business.tin)['available'], 20);
      var calls = 0;
      Future<FiscalReply> send() async {
        calls++;
        return const FiscalReply(
          200,
          '{"receiptID":1,"validationErrors":[{"validationErrorColor":"Red"}]}',
        );
      }

      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: send,
      );
      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: send,
      );
      expect(calls, 1);
      expect(ledger.totals(_business.tin)['available'], 20);
    },
  );

  test(
    'unknown submission reserves one credit and successful retry consumes that reservation',
    () async {
      final reply = await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: () async => throw const SocketException('lost acknowledgement'),
      );
      expect(reply.uncertain, isTrue);
      expect(ledger.totals(_business.tin)['reserved'], 1);
      expect(ledger.totals(_business.tin)['available'], 19);
      await ledger.fiscalise(
        tin: _business.tin,
        deviceId: 123,
        payload: _receipt(1),
        send: () async => const FiscalReply(200, '{"receiptID":1}'),
      );
      expect(ledger.totals(_business.tin)['reserved'], 0);
      expect(ledger.totals(_business.tin)['used'], 1);
      expect(ledger.totals(_business.tin)['available'], 19);
    },
  );

  test('concurrent devices cannot overspend the same trial balance', () async {
    var calls = 0;
    final results = await Future.wait(
      List.generate(21, (i) async {
        try {
          await ledger.fiscalise(
            tin: _business.tin,
            deviceId: i + 1,
            payload: _receipt(1),
            send: () async {
              calls++;
              return FiscalReply(200, '{"receiptID":${i + 1}}');
            },
          );
          return true;
        } on BillingError catch (_) {
          return false;
        }
      }),
    );
    expect(results.where((ok) => ok).length, 20);
    expect(calls, 20);
    expect(ledger.totals(_business.tin)['available'], 0);
  });

  test(
    'test credits and unbound fiscal devices cannot fund production',
    () async {
      final sandbox = BillingService(
        ledger: ledger,
        paynow: paynow,
        publicBaseUrl: Uri.parse('https://example.com'),
        businesses: [_business],
      );
      Future<FiscalReply> never() async => throw StateError('must not submit');
      expect(
        () => sandbox.fiscalise(_business, 123, _receipt(1), never),
        throwsA(isA<BillingError>()),
      );
      expect(
        () => service.fiscalise(_business, 999, _receipt(1), never),
        throwsA(isA<BillingError>()),
      );
    },
  );

  test(
    'HTTP routes require business authentication and reject foreign browser origins',
    () async {
      final secured = BillingService(
        ledger: ledger,
        paynow: paynow,
        publicBaseUrl: Uri.parse('https://billing.example'),
        businesses: [
          VerifiedBusiness(
            _business.tin,
            sha256.convert(utf8.encode('code')).toString(),
            [123],
          ),
        ],
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen(
        (request) => handleBilling(request, secured),
      );
      final client = HttpClient();
      try {
        Future<int> request({String? token, String? origin}) async {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/api/billing/balance'),
          );
          req.headers.contentType = ContentType.json;
          if (token != null) req.headers.set('Authorization', 'Bearer $token');
          if (origin != null) req.headers.set('Origin', origin);
          req.write(jsonEncode({'businessTin': _business.tin}));
          final response = await req.close();
          await response.drain<void>();
          return response.statusCode;
        }

        expect(await request(), 401);
        expect(await request(token: 'code'), 200);
        expect(
          await request(token: 'code', origin: 'https://evil.example'),
          403,
        );
      } finally {
        client.close(force: true);
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
