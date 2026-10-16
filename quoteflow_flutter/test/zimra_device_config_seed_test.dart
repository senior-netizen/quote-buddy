// Regression test for "Fiscalisation failed: Config not loaded. Call
// getConfig() first." (RCP002).
//
// ZimraProvider builds a FRESH ZimraFiscalDevice for every operation. The
// device instance that fetched the config was discarded immediately after
// fetchConfig(), so the next device (the one submitReceipt runs on) had
// _config == null → RCP002. The provider must seed every device it builds
// with the persisted configuration; QR generation (qrDataForPayload reads
// _config.qrUrl) depends on the same seeding.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/services/fiscalisation.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

class _Api implements ZimraApi {
  _Api(this.configResponse);

  final ZimraHttpResponse configResponse;
  int configCalls = 0;
  List<Map<String, dynamic>> submittedBodies = [];
  Completer<void>? submitGate;
  Completer<void>? submitStarted;

  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) {
    if (path.endsWith('/GetConfig')) {
      configCalls++;
      return Future.value(configResponse);
    }
    return Future.value(
      const ZimraHttpResponse(statusCode: 200, body: {}, rawBody: '{}'),
    );
  }

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    if (path.endsWith('/SubmitReceipt')) {
      submittedBodies.add(body);
      if (submitStarted != null && !submitStarted!.isCompleted) {
        submitStarted!.complete();
      }
      await submitGate?.future;
      return Future.value(
        const ZimraHttpResponse(
          statusCode: 200,
          body: {
            'receiptID': 501,
            'operationID': 'OP-TEST-1',
            'receiptDate': '2026-09-25T14:30:05',
          },
          rawBody: '{}',
        ),
      );
    }
    return Future.value(
      const ZimraHttpResponse(statusCode: 200, body: {}, rawBody: '{}'),
    );
  }

  @override
  void close() {}
}

const _configResponse = ZimraHttpResponse(
  statusCode: 200,
  body: {
    'qrUrl': 'https://verify.zimra.example/',
    'applicableTaxes': [
      {'taxID': 101, 'taxName': 'Standard', 'taxPercent': 15.5},
      {'taxID': 103, 'taxName': 'Exempt', 'isExempt': true},
    ],
  },
  rawBody: '{}',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('device-seed-');
    Hive.init(tempDir.path);
    box = await Hive.openBox('zimra');
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  ZimraProvider providerWith(_Api api) {
    final p = ZimraProvider(box, transportFactory: () => api);
    return p;
  }

  Future<void> seedRegisteredDevice() async {
    // Real parseable P-256 key material — submitReceipt signs the canonical
    // string before posting, so the key must decode.
    final pem = encodePrivateKeyPem(generateKeyPair().privateKey);
    await box.putAll({
      'zimra_identity': const ZimraDeviceIdentity(
        deviceId: 38513,
        serialNumber: 'TEST',
      ).toJson(),
      'zimra_credentials': ZimraCredentials(
        privateKeyPem: pem,
        certificatePem: '',
      ).toJson(),
      'zimra_day_state': FiscalDayState(
        status: FiscalDayStatus.fiscalDayOpened,
        fiscalDayNo: 7,
        receiptCounter: 2,
        receiptGlobalNo: 41,
      ).toJson(),
    });
  }

  test(
    'submitReceipt works from the persisted config without a fresh GetConfig',
    () async {
      final api = _Api(_configResponse);
      final provider = providerWith(api);
      await provider.init();
      addTearDown(provider.dispose);
      await seedRegisteredDevice();
      // Re-init so the identity/credentials/day state load.
      final provider2 = providerWith(api);
      await provider2.init();
      addTearDown(provider2.dispose);

      // Fetch config once (the user pressed "Fetch configuration").
      final config = await provider2.fetchConfig();
      expect(config, isNotNull, reason: provider2.error ?? 'fetch failed');
      expect(api.configCalls, 1);

      // Fiscalise WITHOUT any further config fetch.
      final result = await provider2.submitReceipt(
        currency: 'USD',
        invoiceNo: 'INV-2026-0006',
        lines: const [
          ReceiptLineInput(
            name: 'Consulting',
            price: 100,
            quantity: 2,
            taxId: 101,
            taxPercent: 15.5,
          ),
        ],
        payments: const [ReceiptPayment(moneyType: 'Cash', amount: 23100)],
        linesTaxInclusive: false,
      );

      expect(
        result,
        isNotNull,
        reason:
            'RCP002 regression: the provider-built device must carry '
            'the persisted config. Error: ${provider2.lastSubmitError ?? ''}',
      );
      expect(result!.response.receiptId, 501);
      // The QR data must also be built (needs config.qrUrl).
      expect(result.qrData, isNotNull);
      expect(result.qrData, contains('verify.zimra.example'));
      // No extra GetConfig call was needed.
      expect(api.configCalls, 1);
    },
  );

  test(
    'fiscal receipt history beyond 200 records survives submission and restart',
    () async {
      await seedRegisteredDevice();
      await box.put(
        'zimra_receipt_history',
        List.generate(
          201,
          (index) => {
            'receipt': {'invoiceNo': 'HISTORY-$index'},
            'response': FiscalisedReceiptResponse(
              receiptId: index + 1,
            ).toJson(),
          },
        ),
      );
      final provider = providerWith(_Api(_configResponse));
      await provider.init();
      addTearDown(provider.dispose);
      await provider.fetchConfig();
      final result = await provider.submitReceipt(
        currency: 'USD',
        invoiceNo: 'NEW-RECEIPT',
        lines: const [
          ReceiptLineInput(
            name: 'Consulting',
            price: 100,
            quantity: 2,
            taxId: 101,
            taxPercent: 15.5,
          ),
        ],
        payments: const [ReceiptPayment(moneyType: 'Cash', amount: 23100)],
        linesTaxInclusive: false,
      );
      expect(result, isNotNull);
      final stored = box.get('zimra_receipt_history') as List;
      expect(stored, hasLength(202));
      expect((stored.last as Map)['receipt']['invoiceNo'], 'HISTORY-200');
      final restored = providerWith(_Api(_configResponse));
      await restored.init();
      addTearDown(restored.dispose);
      expect(restored.receiptHistory, hasLength(202));
    },
  );

  test('QR data is unavailable when no config has ever been fetched', () async {
    final api = _Api(_configResponse);
    final provider = providerWith(api);
    await provider.init();
    addTearDown(provider.dispose);
    await seedRegisteredDevice();

    // No fetchConfig() ran — the device has no qrUrl and must NOT crash,
    // but fiscalisation cannot proceed through the provider preflight
    // (effectiveConfig is null → validateFiscalisation reports it).
    expect(provider.effectiveConfig, isNull);
    final preflight = validateFiscalisation(
      doc: null,
      org: null,
      zimra: provider,
    );
    expect(preflight.ok, isFalse);
  });

  test(
    'overlapping submissions use consecutive persisted receipt numbers',
    () async {
      await seedRegisteredDevice();
      final api = _Api(_configResponse)
        ..submitGate = Completer<void>()
        ..submitStarted = Completer<void>();
      final provider = providerWith(api);
      await provider.init();
      addTearDown(provider.dispose);
      await provider.fetchConfig();
      Future<FiscalisedReceipt?> submit(String invoice) =>
          provider.submitReceipt(
            currency: 'USD',
            invoiceNo: invoice,
            lines: const [
              ReceiptLineInput(
                name: 'Item',
                price: 10,
                quantity: 1,
                taxId: 103,
              ),
            ],
            payments: const [ReceiptPayment(moneyType: 'Cash', amount: 1000)],
          );
      // The seeded day has no opening date, so close fails locally. A failed
      // operation must release the queue for subsequent submissions.
      await expectLater(provider.closeDay(), throwsA(isA<ZimraException>()));
      final first = submit('FIRST');
      await api.submitStarted!.future;
      final second = submit('SECOND');
      await Future<void>.delayed(Duration.zero);
      expect(api.submittedBodies.length, 1);
      api.submitGate!.complete();
      expect(await first, isNotNull);
      expect(await second, isNotNull);
      expect(
        api.submittedBodies.map(
          (b) => (b['receipt'] as Map)['receiptGlobalNo'],
        ),
        [42, 43],
      );
      final restored = providerWith(api);
      await restored.init();
      addTearDown(restored.dispose);
      expect(restored.dayState.receiptGlobalNo, 43);
      expect(restored.dayState.receiptCounter, 4);
    },
  );

  test('successful manual retry removes its persisted offline entry', () async {
    await seedRegisteredDevice();
    final payload = <String, dynamic>{
      'receipt': {
        'receiptGlobalNo': 41,
        'receiptCounter': 2,
        'receiptDate': '2026-09-29T12:00:00',
        'receiptType': 'FiscalInvoice',
        'receiptCurrency': 'USD',
        'receiptLinesTaxInclusive': false,
        'receiptDeviceSignature': {'hash': 'AA==', 'signature': 'AA=='},
        'receiptLines': [
          {
            'receiptLineNo': 1,
            'receiptLineName': 'Service',
            'receiptLinePrice': 10,
            'receiptLineQuantity': 1,
            'receiptLineTotal': 10,
            'receiptLineType': 'Sale',
            'taxID': 103,
          },
        ],
        'receiptTaxes': [
          {'taxID': 103, 'taxAmount': 0, 'salesAmountWithTax': 10},
        ],
        'receiptPayments': [
          {'moneyTypeCode': 'Cash', 'paymentAmount': 10},
        ],
        'receiptTotal': 10,
      },
    };
    await box.put('zimra_offline_queue', [
      PendingReceipt(
        id: 'pending',
        receiptPayload: payload,
        createdAt: DateTime.now(),
        fiscalDayNo: 7,
        receiptGlobalNo: 41,
      ).toJson(),
    ]);
    final api = _Api(_configResponse);
    final provider = providerWith(api);
    await provider.init();
    addTearDown(provider.dispose);
    await provider.fetchConfig();
    expect(await provider.resubmitReceipt(payload), isNotNull);
    expect(provider.offlineQueue, isEmpty);
    final restored = providerWith(api);
    await restored.init();
    addTearDown(restored.dispose);
    expect(restored.offlineQueue, isEmpty);
    expect(restored.dayState.receiptGlobalNo, 41);
  });
}
