// Close-day contract tests.
//
// Schema source: the live TEST contract at
// https://fdmsapitest.zimra.co.zw/swagger/Device-v1/swagger.json
// (CloseDayRequest = fiscalDayNo + fiscalDayCounters[] +
// fiscalDayDeviceSignature{hash,signature} + receiptCounter, all required,
// additionalProperties: false).
//
// CASE A  fiscal day with 0 receipts
// CASE B  fiscal day with one or more fiscal receipts
// CASE C  missing/invalid counters are caught locally, before any request
// CASE D  successful CloseDay response resets local fiscal-day state
// CASE E  ZIMRA 400 produces a readable diagnostic and corrupts nothing

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

/// Scripted FDMS transport — records every request, never touches the network.
class _FakeApi implements ZimraApi {
  final List<String> paths = [];
  final List<Map<String, dynamic>> bodies = [];
  ZimraHttpResponse Function(String path, Map<String, dynamic> body)? responder;

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    paths.add(path);
    bodies.add(body);
    final respond = responder;
    if (respond == null) {
      return const ZimraHttpResponse(statusCode: 200, body: {}, rawBody: '{}');
    }
    return respond(path, body);
  }

  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) =>
      post(path, body: const {});

  @override
  void close() {}
}

ZimraCredentials _credentials() {
  final pair = generateKeyPair();
  return ZimraCredentials(
    privateKeyPem: encodePrivateKeyPem(pair.privateKey),
    certificatePem: '',
  );
}

FiscalDayState _openDay({int dayNo = 1, int receipts = 0, int global = 0}) =>
    FiscalDayState(
      fiscalDayNo: dayNo,
      fiscalDayDate: '2026-09-25',
      receiptCounter: receipts,
      receiptGlobalNo: global,
      status: FiscalDayStatus.fiscalDayOpened,
    );

Map<String, dynamic> _pendingPayload(int number) => {
  'receipt': {
    'receiptGlobalNo': number,
    'receiptCounter': number,
    'receiptDate': '2026-09-29T12:00:00',
    'receiptType': 'FiscalInvoice',
    'receiptCurrency': 'USD',
    'receiptLinesTaxInclusive': false,
    'receiptDeviceSignature': {'hash': 'AA==', 'signature': 'AA=='},
    'receiptLines': [
      {
        'receiptLineNo': 1,
        'receiptLineName': 'Item',
        'receiptLinePrice': 10,
        'receiptLineQuantity': 1,
        'receiptLineTotal': 10,
        'receiptLineType': 'Sale',
        'taxID': 927,
        'taxPercent': 0,
      },
    ],
    'receiptTaxes': [
      {'taxID': 927, 'taxPercent': 0, 'taxAmount': 0, 'salesAmountWithTax': 10},
    ],
    'receiptPayments': [
      {'moneyTypeCode': 'Cash', 'paymentAmount': 10},
    ],
    'receiptTotal': 10,
  },
};

void main() {
  late ZimraCredentials credentials;
  late _FakeApi api;
  final logs = <String>[];

  setUp(() {
    credentials = _credentials();
    api = _FakeApi();
    logs.clear();
    ZimraFiscalDevice.logTraffic = true;
    ZimraFiscalDevice.trafficLogger = logs.add;
  });

  tearDown(() {
    ZimraFiscalDevice.trafficLogger = null;
    ZimraFiscalDevice.logTraffic = true;
  });

  ZimraFiscalDevice device({FiscalDayState? state}) => ZimraFiscalDevice(
    identity: const ZimraDeviceIdentity(
      deviceId: 38513,
      serialNumber: '2002367692-026',
    ),
    credentials: credentials,
    environment: ZimraEnvironment.test,
    dayState: state ?? _openDay(),
    transport: api,
    config: const ZimraConfig(
      applicableTaxes: [
        ZimraTax(taxId: 927, taxCode: '', taxName: 'Non-VAT 0%', taxPercent: 0),
      ],
      qrUrl: '',
    ),
  );

  group('CASE A — fiscal day with zero receipts', () {
    test('offline payload restores from Hive maps with dynamic keys', () {
      final pending = PendingReceipt.fromJson({
        'id': 'persisted',
        'receiptPayload': <dynamic, dynamic>{
          'receipt': <dynamic, dynamic>{'receiptGlobalNo': 42},
        },
        'createdAt': '2026-09-25T12:00:00',
        'fiscalDayNo': 1,
        'receiptGlobalNo': 42,
      });
      expect((pending.receiptPayload['receipt'] as Map)['receiptGlobalNo'], 42);
    });
    test('retry validation errors block day closure', () async {
      final d = device();
      api.responder = (path, body) => const ZimraHttpResponse(
        statusCode: 200,
        body: {
          'validationErrors': [
            {'validationErrorCode': 'TEST_RED', 'validationErrorColor': 'Red'},
          ],
        },
        rawBody: '{}',
      );
      await d.resubmitReceipt(_pendingPayload(1));
      expect(d.dayState.redErrors, contains('TEST_RED'));
      await expectLater(d.closeDay(), throwsA(isA<ZimraException>()));
      expect(api.paths.length, 1);
    });
    test(
      'opening the next day preserves the global receipt sequence',
      () async {
        final d = device(state: FiscalDayState(receiptGlobalNo: 42));
        api.responder = (path, body) => const ZimraHttpResponse(
          statusCode: 200,
          body: {'fiscalDayNo': 3},
          rawBody: '{}',
        );
        await d.openDay();
        expect(d.dayState.receiptGlobalNo, 42);
        expect(d.dayState.receiptCounter, 0);
      },
    );

    test('status refresh preserves offline numbering and counters', () async {
      final d = device(state: _openDay(receipts: 2, global: 42));
      d.dayState.counters.add(
        const FiscalDayCounter(
          type: 'BalanceByMoneyType',
          currency: 'USD',
          moneyType: 'Cash',
          value: 10,
        ),
      );
      d.queueOfflineReceipt(
        receiptPayload: {},
        fiscalDayNo: 1,
        receiptGlobalNo: 42,
      );
      api.responder = (path, body) => const ZimraHttpResponse(
        statusCode: 200,
        body: {
          'fiscalDayStatus': 'FiscalDayOpened',
          'lastReceiptGlobalNo': 41,
          'fiscalDayCounter': [],
        },
        rawBody: '{}',
      );
      await d.getStatus();
      expect(d.dayState.receiptGlobalNo, 42);
      expect(d.dayState.counters.single.value, 10);
      await expectLater(
        d.closeDay(force: true),
        throwsA(isA<ZimraException>()),
      );
      expect(api.paths.every((p) => p.endsWith('/GetStatus')), isTrue);
    });

    test('offline flush stops at the first failed receipt', () async {
      final d = device();
      for (var n = 1; n <= 3; n++) {
        d.queueOfflineReceipt(
          receiptPayload: _pendingPayload(n),
          fiscalDayNo: 1,
          receiptGlobalNo: n,
        );
      }
      api.responder = (path, body) =>
          const ZimraHttpResponse(statusCode: 400, body: {}, rawBody: '{}');
      expect(await d.flushOfflineQueue(), isEmpty);
      expect(api.paths.length, 1);
      expect(d.offlineQueue.map((p) => p.receiptGlobalNo), [1, 2, 3]);
    });

    test(
      'CloseDayRequest carries every required field, receiptCounter = 0',
      () async {
        final d = device(state: _openDay());
        await d.closeDay();

        expect(api.paths, ['/Device/v1/38513/CloseDay']);
        final body = api.bodies.single;

        // Exact contract — no wrapper, no extra properties.
        expect(body.keys.toSet(), {
          'fiscalDayNo',
          'fiscalDayCounters',
          'fiscalDayDeviceSignature',
          'receiptCounter',
        });
        expect(body['fiscalDayNo'], 1);
        expect(body['receiptCounter'], 0, reason: 'zero-receipt day sends 0');
        expect(body['fiscalDayCounters'], isEmpty);

        final sig = body['fiscalDayDeviceSignature'];
        expect(sig, isA<Map<String, dynamic>>());
        expect(sig.keys.toSet(), {'hash', 'signature'});
        // 32-byte SHA-256, base64 encoded = 44 chars.
        expect((sig['hash'] as String).length, 44);
        expect(base64Decode(sig['hash'] as String).length, 32);
        expect(base64Decode(sig['signature'] as String), isNotEmpty);

        // Hash is the base64 SHA-256 of deviceId + dayNo + dayDate for a day
        // without counters.
        final expectedHash = base64Encode(
          sha256.convert(utf8.encode('3851312026-09-25')).bytes,
        );
        expect(sig['hash'], expectedHash);
      },
    );
  });

  group('CASE B — fiscal day with receipts', () {
    test('counters serialize as FiscalDayCounterDto, zero values dropped', () {
      final state = _openDay(receipts: 3, global: 3)
        ..counters = [
          const FiscalDayCounter(
            type: 'BalanceByMoneyType',
            currency: 'USD',
            moneyType: 'Cash',
            value: 115,
          ),
          const FiscalDayCounter(
            type: 'SaleTaxByTax',
            currency: 'USD',
            taxId: 101,
            taxPercent: 15,
            value: 15,
          ),
          const FiscalDayCounter(
            type: 'SaleByTax',
            currency: 'USD',
            taxId: 101,
            taxPercent: 15,
            value: 115,
          ),
          // Zero-value counter: present locally, dropped on the wire.
          const FiscalDayCounter(
            type: 'SaleByTax',
            currency: 'USD',
            taxId: 202,
            taxPercent: 0,
            value: 0,
          ),
        ];

      final body = ZimraFiscalDevice.buildCloseDayRequest(
        deviceId: 38513,
        state: state,
        privateKeyPem: credentials.privateKeyPem,
      );

      expect(body['receiptCounter'], 3);
      final counters = body['fiscalDayCounters'] as List;
      expect(counters, hasLength(3));

      // Field names are the DTO's, values are major units (dollars).
      final sale =
          counters.firstWhere((c) => c['fiscalCounterType'] == 'SaleByTax')
              as Map<String, dynamic>;
      expect(sale.keys.toSet(), {
        'fiscalCounterType',
        'fiscalCounterCurrency',
        'fiscalCounterTaxID',
        'fiscalCounterTaxPercent',
        'fiscalCounterValue',
      });
      expect(sale['fiscalCounterCurrency'], 'USD');
      expect(sale['fiscalCounterTaxID'], 101);
      expect(sale['fiscalCounterTaxPercent'], 15.0);
      expect(sale['fiscalCounterValue'], 115.0);

      final balance =
          counters.firstWhere(
                (c) => c['fiscalCounterType'] == 'BalanceByMoneyType',
              )
              as Map<String, dynamic>;
      expect(balance['fiscalCounterMoneyType'], 'Cash');
      expect(balance.containsKey('fiscalCounterTaxID'), isFalse);
    });

    test('canonical signing string matches the FDMS/SDK construction', () {
      final state = _openDay(receipts: 3, global: 3)
        ..counters = [
          const FiscalDayCounter(
            type: 'BalanceByMoneyType',
            currency: 'USD',
            moneyType: 'Cash',
            value: 115,
          ),
          const FiscalDayCounter(
            type: 'SaleByTax',
            currency: 'USD',
            taxId: 101,
            taxPercent: 15,
            value: 115,
          ),
          const FiscalDayCounter(
            type: 'SaleTaxByTax',
            currency: 'USD',
            taxId: 101,
            taxPercent: 15,
            value: 15,
          ),
        ];

      final canonical = ZimraFiscalDevice.buildCloseDaySigningString(
        38513,
        state,
      );
      expect(
        canonical,
        '3851312026-09-25'
        'SALEBYTAXUSD15.0011500'
        'SALETAXBYTAXUSD15.001500'
        'BALANCEBYMONEYTYPEUSDCASH11500',
      );
      // Sorted by counter type order (Sale=1, SaleTax=2, Balance=7) and the
      // sent hash equals SHA-256 of exactly this string.
      final body = ZimraFiscalDevice.buildCloseDayRequest(
        deviceId: 38513,
        state: state,
        privateKeyPem: credentials.privateKeyPem,
      );
      final hash = (body['fiscalDayDeviceSignature'] as Map)['hash'];
      expect(hash, base64Encode(sha256.convert(utf8.encode(canonical)).bytes));
    });
  });

  group('CASE C — local validation before any request', () {
    test('missing fiscal day number is rejected locally', () async {
      final state = _openDay();
      state.fiscalDayNo = null;
      final d = device(state: state);

      await expectLater(
        d.closeDay(),
        throwsA(isA<ZimraException>().having((e) => e.code, 'code', 'DAY005')),
      );
      expect(api.paths, isEmpty, reason: 'nothing may reach FDMS');
      expect(d.dayState.isOpen, isTrue, reason: 'state untouched');
    });

    test('missing fiscal day date is rejected locally', () async {
      final state = _openDay();
      state.fiscalDayDate = null;
      final d = device(state: state);

      await expectLater(
        d.closeDay(),
        throwsA(isA<ZimraException>().having((e) => e.code, 'code', 'DAY005')),
      );
      expect(api.paths, isEmpty);
    });

    test('invalid receipt counters are rejected locally', () {
      final bad = _openDay()
        ..counters = [
          const FiscalDayCounter(
            type: 'NotAnFdmsType',
            currency: 'USD',
            taxId: 1,
            value: 5,
          ),
        ];
      expect(
        () => ZimraFiscalDevice.buildCloseDayRequest(
          deviceId: 38513,
          state: bad,
          privateKeyPem: credentials.privateKeyPem,
        ),
        throwsA(isA<ZimraException>().having((e) => e.code, 'code', 'DAY006')),
      );

      final badCurrency = _openDay()
        ..counters = [
          const FiscalDayCounter(
            type: 'SaleByTax',
            currency: 'US',
            taxId: 1,
            value: 5,
          ),
        ];
      expect(
        () => ZimraFiscalDevice.buildCloseDayRequest(
          deviceId: 38513,
          state: badCurrency,
          privateKeyPem: credentials.privateKeyPem,
        ),
        throwsA(isA<ZimraException>().having((e) => e.code, 'code', 'DAY006')),
      );
    });
  });

  group('CASE D — successful response updates local state', () {
    test(
      'failed asynchronous closure retains counters and can be retried',
      () async {
        final d = device(state: _openDay(receipts: 2, global: 5));
        await d.closeDay();
        api.responder = (path, body) => const ZimraHttpResponse(
          statusCode: 200,
          body: {'fiscalDayStatus': 'FiscalDayCloseFailed'},
          rawBody: '{}',
        );
        await d.getStatus();
        expect(d.dayState.status, FiscalDayStatus.fiscalDayCloseFailed);
        expect(d.dayState.receiptCounter, 2);
        await d.closeDay();
        expect(api.paths.where((p) => p.endsWith('/CloseDay')).length, 2);
        expect(d.dayState.status, FiscalDayStatus.fiscalDayCloseInitiated);
      },
    );

    test('missing server status cannot confirm closure', () async {
      final d = device(state: _openDay(receipts: 2));
      await d.closeDay();
      await expectLater(d.getStatus(), throwsA(isA<ZimraException>()));
      expect(d.dayState.status, FiscalDayStatus.fiscalDayCloseInitiated);
      expect(d.dayState.receiptCounter, 2);
    });

    test(
      'accepted CloseDay preserves the day until confirmed closed',
      () async {
        api.responder = (path, body) => const ZimraHttpResponse(
          statusCode: 200,
          body: {'operationID': '0HNOORM8EBTEN:00000002'},
          rawBody: '{"operationID":"0HNOORM8EBTEN:00000002"}',
        );
        final d = device(state: _openDay(receipts: 2, global: 2));

        await d.closeDay();

        final state = d.dayState;
        expect(state.status, FiscalDayStatus.fiscalDayCloseInitiated);
        expect(state.fiscalDayNo, 1);
        expect(state.receiptCounter, 2);
        expect(state.receiptGlobalNo, 2);
        expect(state.counters, isEmpty);
        expect(state.previousReceiptHash, isNull);
        await d.closeDay();
        expect(
          api.paths.length,
          1,
          reason: 'Pending closure is not resubmitted',
        );
        api.responder = (path, body) => const ZimraHttpResponse(
          statusCode: 200,
          body: {'fiscalDayStatus': 'FiscalDayClosed'},
          rawBody: '{}',
        );
        await d.getStatus();
        expect(d.dayState.isClosed, isTrue);
        expect(d.dayState.fiscalDayNo, isNull);
        expect(d.dayState.receiptGlobalNo, 2);
      },
    );
  });

  group('CASE E — ZIMRA 400 keeps everything intact', () {
    test('readable diagnostic, day preserved, retry possible', () async {
      final problem = {
        'type': 'https://httpstatuses.io/400',
        'title': 'Bad Request',
        'status': 400,
        'errors': {
          r'$': [
            "JSON deserialization for type 'FiscalisationBackend."
                "FiscalDeviceApi.Models.V1.Requests.CloseDayRequest' was "
                "missing required properties including: 'receiptCounter'.",
          ],
          'closeDayRequest': ['The closeDayRequest field is required.'],
        },
        'operationID': '0HNOORM8EG66R:00000001',
      };
      api.responder = (path, body) => ZimraHttpResponse(
        statusCode: 400,
        body: problem,
        rawBody: jsonEncode(problem),
      );

      final d = device(state: _openDay(receipts: 1, global: 7));
      d.dayState.counters = [
        const FiscalDayCounter(
          type: 'SaleByTax',
          currency: 'USD',
          taxId: 101,
          taxPercent: 15,
          value: 115,
        ),
      ];

      final error = await d.closeDay().then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );

      expect(error, isA<ZimraException>());
      final zimra = error! as ZimraException;
      expect(zimra.code, 'DAY004');
      expect(zimra.message, contains('400'));
      expect(
        zimra.message,
        contains('receiptCounter'),
        reason: 'the server field names must surface verbatim',
      );
      expect(zimra.message, contains('The closeDayRequest field is required'));

      // State safety: everything preserved for a retry.
      final state = d.dayState;
      expect(state.isOpen, isTrue);
      expect(state.fiscalDayNo, 1);
      expect(state.receiptCounter, 1);
      expect(state.receiptGlobalNo, 7);
      expect(state.counters, hasLength(1));

      // Retry is possible and hits the endpoint again.
      await expectLater(d.closeDay(), throwsA(isA<ZimraException>()));
      expect(api.paths, hasLength(2));

      // TEST diagnostics: request + response were logged, sanitized.
      final all = logs.join('\n');
      expect(all, contains('ZIMRA CloseDay Request:'));
      expect(all, contains('ZIMRA CloseDay Response:'));
      expect(all, contains('HTTP 400'));
      expect(all, contains('receiptCounter'));
      expect(all, isNot(contains('PRIVATE KEY')));
      expect(all, isNot(contains(credentials.privateKeyPem.split('\n').last)));
    });
  });
}
