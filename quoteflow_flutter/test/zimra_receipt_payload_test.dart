// SubmitReceipt contract tests — the fiscal-document flow depends on this.
//
// Schema source: the live TEST contract at
// https://fdmsapitest.zimra.co.zw/swagger/Device-v1/swagger.json
// (SubmitReceiptRequest = { receipt: ReceiptDto }, all amounts in major
// units, receiptDeviceSignature {hash, signature}).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra.dart';
import 'package:quoteflow/services/zimra/buyer_contract.dart';

/// Scripted FDMS transport — records every request, never touches network.
class _FakeApi implements ZimraApi {
  final List<String> paths = [];
  final List<Map<String, dynamic>> bodies = [];
  ZimraHttpResponse Function(String path, Map<String, dynamic> body)? responder;

  /// When set, [post] throws it (simulated network outage).
  Object? failWith;

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    paths.add(path);
    bodies.add(body);
    final failure = failWith;
    if (failure != null) throw failure;
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

const _qrUrl = 'https://verify.zimra.example/';

const _configJson = {
  'qrUrl': _qrUrl,
  'applicableTaxes': [
    {'taxId': 101, 'taxCode': '15', 'taxName': '15%', 'taxPercent': 15},
    {'taxId': 102, 'taxCode': '0', 'taxName': '0%', 'taxPercent': 0},
    {'taxId': 103, 'taxName': 'exempt', 'isExempt': true},
  ],
};

final _submitOkJson = {
  'operationID': '0HMQCKLK5B38G:00000006',
  'receiptID': 501,
  'serverDate': '2026-09-25T14:30:05',
  'receiptServerSignature': {
    'hash': base64Encode(List<int>.filled(32, 7)),
    'signature': base64Encode(List<int>.filled(64, 9)),
    'certificateThumbprint': 'F9B295CA65BA22B94F6D4B27E48D08BF6CD7F7C8',
  },
};

void main() {
  late ZimraCredentials credentials;
  late _FakeApi api;

  setUp(() {
    final pair = generateKeyPair();
    credentials = ZimraCredentials(
      privateKeyPem: encodePrivateKeyPem(pair.privateKey),
      certificatePem: '',
    );
    api = _FakeApi();
    ZimraFiscalDevice.logTraffic = false;
    ZimraFiscalDevice.trafficLogger = null;
  });

  Future<ZimraFiscalDevice> openDevice() async {
    final d = ZimraFiscalDevice(
      identity: const ZimraDeviceIdentity(
        deviceId: 38513,
        serialNumber: '2002367692-026',
      ),
      credentials: credentials,
      environment: ZimraEnvironment.test,
      dayState: FiscalDayState(
        fiscalDayNo: 1,
        fiscalDayDate: '2026-09-25',
        status: FiscalDayStatus.fiscalDayOpened,
      ),
      transport: api,
    );
    api.responder = (path, body) {
      if (path.endsWith('/GetConfig')) {
        return ZimraHttpResponse(
          statusCode: 200,
          body: _configJson,
          rawBody: jsonEncode(_configJson),
        );
      }
      if (path.endsWith('/SubmitReceipt')) {
        return ZimraHttpResponse(
          statusCode: 200,
          body: _submitOkJson,
          rawBody: jsonEncode(_submitOkJson),
        );
      }
      return const ZimraHttpResponse(statusCode: 404, body: {}, rawBody: '');
    };
    await d.getConfig();
    return d;
  }

  final taxableLines = [
    const ReceiptLineInput(
      name: 'Consulting Services',
      price: 100,
      quantity: 1,
      taxId: 101,
      taxPercent: 15,
      taxCode: '15',
    ),
  ];

  for (final type in [ReceiptType.creditNote, ReceiptType.debitNote]) {
    test(
      '${type.apiValue} requires original invoice before submission',
      () async {
        final d = await openDevice();
        final requests = api.paths.length;
        await expectLater(
          d.submitReceipt(
            currency: 'USD',
            invoiceNo: 'NOTE',
            receiptType: type,
            lines: taxableLines,
            payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
            linesTaxInclusive: false,
          ),
          throwsA(isA<ZimraException>()),
        );
        expect(api.paths.length, requests);
        expect(d.dayState.receiptCounter, 0);
        expect(d.offlineQueue, isEmpty);
      },
    );
    test(
      '${type.apiValue} transmits original fiscal invoice reference',
      () async {
        final d = await openDevice();
        await d.submitReceipt(
          currency: 'USD',
          invoiceNo: 'NOTE',
          receiptType: type,
          lines: taxableLines,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
          linesTaxInclusive: false,
          creditDebitNote: const CreditDebitNoteRef(
            receiptId: 900,
            deviceId: 38513,
            receiptGlobalNo: 42,
            fiscalDayNo: 4,
          ),
        );
        final body =
            api.bodies[api.paths.lastIndexWhere(
              (p) => p.endsWith('/SubmitReceipt'),
            )];
        expect((body['receipt'] as Map)['creditDebitNote'], {
          'receiptID': 900,
          'deviceID': 38513,
          'receiptGlobalNo': 42,
          'fiscalDayNo': 4,
        });
      },
    );
  }

  test(
    'partial buyer is blocked before signing, transport or counters advance',
    () async {
      final d = await openDevice();
      final requests = api.paths.length;
      await expectLater(
        d.submitReceipt(
          currency: 'USD',
          invoiceNo: 'BAD',
          lines: taxableLines,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
          linesTaxInclusive: false,
          buyer: const BuyerData(name: 'ABC'),
        ),
        throwsA(isA<FiscalBuyerException>()),
      );
      expect(api.paths.length, requests);
      expect(d.dayState.receiptCounter, 0);
      expect(d.offlineQueue, isEmpty);
    },
  );

  test(
    'buyer is omitted or complete on the actual wire; malformed retry blocked',
    () async {
      final d = await openDevice();
      for (final buyer in [
        null,
        const BuyerData(name: 'ABC Ltd', tin: '1234567890'),
        const BuyerData(
          name: 'ABC Ltd',
          tin: '1234567890',
          vatNumber: '123456789',
        ),
      ]) {
        final result = await d.submitReceipt(
          currency: 'USD',
          invoiceNo: 'INV',
          lines: taxableLines,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
          linesTaxInclusive: false,
          buyer: buyer,
        );
        final sent = api.bodies.last['receipt'] as Map;
        expect(sent.containsKey('buyerData'), buyer != null);
        if (buyer != null) expect(sent['buyerData'], buyer.toJson());
        final bad =
            jsonDecode(jsonEncode(result.receipt)) as Map<String, dynamic>;
        (bad['receipt'] as Map)['buyerData'] = <String, dynamic>{};
        final requests = api.paths.length;
        await expectLater(
          d.resubmitReceipt(bad),
          throwsA(isA<ZimraException>()),
        );
        expect(api.paths.length, requests);
      }
    },
  );

  test(
    'debug log preserves buyer shape but redacts personal information',
    () async {
      final d = await openDevice();
      final logs = <String>[];
      ZimraFiscalDevice.logTraffic = true;
      ZimraFiscalDevice.trafficLogger = logs.add;
      await d.submitReceipt(
        currency: 'USD',
        invoiceNo: 'PRIVATE-INVOICE',
        lines: taxableLines,
        payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
        linesTaxInclusive: false,
        buyer: const BuyerData(
          name: 'Private Customer Ltd',
          tin: '1234567890',
          buyerContacts: {'email': 'private@example.test'},
        ),
      );
      final request = logs.firstWhere(
        (log) => log.contains('SubmitReceipt Request'),
      );
      expect(request, contains('buyerRegisterName'));
      expect(request, contains('buyerTIN'));
      expect(request, contains('buyerContacts'));
      for (final secret in [
        'Private Customer Ltd',
        '1234567890',
        'private@example.test',
        'PRIVATE KEY',
      ]) {
        expect(request, isNot(contains(secret)));
      }
    },
  );

  group('successful fiscal receipt (cases A + B)', () {
    test(
      'payload follows the ReceiptDto contract and signs canonically',
      () async {
        final d = await openDevice();

        final totalCents = ZimraFiscalDevice.computeReceiptTotalCents(
          taxableLines,
          linesTaxInclusive: false,
        );
        expect(totalCents, 11500);

        final result = await d.submitReceipt(
          currency: 'USD',
          invoiceNo: 'INV-001',
          lines: taxableLines,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: totalCents)],
          linesTaxInclusive: false,
          receiptDate: DateTime(2026, 9, 25, 14, 30),
        );

        final path = api.paths.last;
        expect(path, '/Device/v1/38513/SubmitReceipt');
        final sent = api.bodies.last;
        expect(sent.keys.toSet(), {
          'receipt',
        }, reason: 'SubmitReceiptRequest wraps ReceiptDto in "receipt"');

        final receipt = sent['receipt'] as Map<String, dynamic>;
        expect(receipt.keys.toSet(), {
          'receiptType',
          'receiptCurrency',
          'receiptCounter',
          'receiptGlobalNo',
          'invoiceNo',
          'receiptDate',
          'receiptLinesTaxInclusive',
          'receiptLines',
          'receiptTaxes',
          'receiptPayments',
          'receiptTotal',
          'receiptPrintForm',
          'receiptDeviceSignature',
        });
        expect(receipt['receiptType'], 'FiscalInvoice');
        expect(receipt['receiptCurrency'], 'USD');
        expect(receipt['receiptCounter'], 1);
        expect(receipt['receiptGlobalNo'], 1);
        expect(receipt['receiptDate'], '2026-09-25T14:30:00');
        expect(receipt['receiptLinesTaxInclusive'], false);

        // Amounts are major units (dollars), not cents.
        expect(receipt['receiptTotal'], 115.0);
        final line = (receipt['receiptLines'] as List).single as Map;
        expect(line['receiptLineType'], 'Sale');
        expect(line['receiptLineNo'], 1);
        expect(line['receiptLinePrice'], 100.0);
        expect(line['receiptLineTotal'], 100.0);
        expect(line['taxID'], 101);
        expect(line['taxPercent'], 15.0);
        final tax = (receipt['receiptTaxes'] as List).single as Map;
        expect(tax['taxAmount'], 15.0);
        expect(tax['salesAmountWithTax'], 115.0);
        final payment = (receipt['receiptPayments'] as List).single as Map;
        expect(payment.keys.toSet(), {'moneyTypeCode', 'paymentAmount'});
        expect(payment['moneyTypeCode'], 'Cash');
        expect(payment['paymentAmount'], 115.0);

        // Signature: hash = base64(SHA-256(canonical)), canonical built per
        // FDMS: deviceId + TYPE + CURRENCY + globalNo + date + total(cents) +
        // taxes + previousHash.
        final sig = receipt['receiptDeviceSignature'] as Map;
        expect(sig.keys.toSet(), {'hash', 'signature'});
        final canonical =
            '38513'
            'FISCALINVOICE'
            'USD'
            '1'
            '2026-09-25T14:30:00'
            '11500'
            '15.00'
            '1500'
            '11500';
        expect(
          sig['hash'],
          base64Encode(sha256.convert(utf8.encode(canonical)).bytes),
        );
        expect(base64Decode(sig['signature'] as String), isNotEmpty);

        // Response parsing (FDMS response field names).
        expect(result.response.receiptId, 501);
        expect(result.response.serverDate, '2026-09-25T14:30:05');
        expect(result.response.serverHash, isNotNull);
        expect(result.response.signature, isNotNull);
        expect(result.response.certificateThumbprint, startsWith('F9B2'));
        expect(result.response.operationId, '0HMQCKLK5B38G:00000006');

        // Local state advanced once, on acceptance.
        expect(d.dayState.receiptCounter, 1);
        expect(d.dayState.receiptGlobalNo, 1);
        expect(d.dayState.previousReceiptHash, sig['hash']);
      },
    );

    test('verification QR payload follows the FDMS QR construction', () async {
      final d = await openDevice();
      final result = await d.submitReceipt(
        currency: 'USD',
        invoiceNo: 'INV-001',
        lines: taxableLines,
        payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
        linesTaxInclusive: false,
        receiptDate: DateTime(2026, 9, 25, 14, 30),
      );

      final sent = api.bodies.last;
      final deviceSig =
          ((sent['receipt'] as Map)['receiptDeviceSignature']
                  as Map)['signature']
              as String;
      final md5_16 = md5
          .convert(base64Decode(deviceSig))
          .toString()
          .substring(0, 16);

      expect(
        result.qrData,
        '$_qrUrl'
        '0000038513' // deviceId, padded to 10
        '25092026' // ddMMyyyy
        '0000000001' // receiptGlobalNo, padded to 10
        '$md5_16', // first 16 hex chars of MD5(raw signature bytes)
      );
      // The stored QR payload round-trips to the same value.
      expect(d.qrDataForPayload(result.receipt), result.qrData);
    });
  });

  group('zero-value / edge cases (case I)', () {
    test('exempt line produces no tax and an empty tax-percent slot', () async {
      final d = await openDevice();
      const exemptLines = [
        ReceiptLineInput(
          name: 'Exempt Service',
          price: 50,
          quantity: 1,
          taxId: 103,
          taxPercent: null,
        ),
      ];
      final totalCents = ZimraFiscalDevice.computeReceiptTotalCents(
        exemptLines,
        linesTaxInclusive: false,
      );
      expect(totalCents, 5000);

      final result = await d.submitReceipt(
        currency: 'USD',
        invoiceNo: 'INV-EX',
        lines: exemptLines,
        payments: [ReceiptPayment(moneyType: 'Cash', amount: totalCents)],
        linesTaxInclusive: false,
        receiptDate: DateTime(2026, 9, 25, 15, 0),
      );

      final receipt = api.bodies.last['receipt'] as Map;
      expect(receipt['receiptTotal'], 50.0);
      final tax = (receipt['receiptTaxes'] as List).single as Map;
      expect(tax.containsKey('taxPercent'), isFalse);
      expect(tax['taxAmount'], 0.0);
      expect(tax['salesAmountWithTax'], 50.0);
      expect(result.qrData, isNotNull);
    });

    test(
      'payments that do not match the receipt total are rejected locally',
      () async {
        final d = await openDevice();
        final requestsBefore = api.paths.length;

        await expectLater(
          d.submitReceipt(
            currency: 'USD',
            invoiceNo: 'INV-BAD',
            lines: taxableLines,
            payments: [ReceiptPayment(moneyType: 'Cash', amount: 1)],
            linesTaxInclusive: false,
          ),
          throwsA(
            isA<ZimraException>().having((e) => e.code, 'code', 'RCP010'),
          ),
        );
        expect(api.paths.length, requestsBefore, reason: 'nothing was sent');
        expect(d.dayState.receiptCounter, 0, reason: 'state untouched');
      },
    );
  });

  group('offline fiscalisation (FDMS grace window)', () {
    test(
      'network failure journals the signed receipt and keeps numbering',
      () async {
        final d = await openDevice();
        api.failWith = const SocketException('network down');

        final error = await d
            .submitReceipt(
              currency: 'USD',
              invoiceNo: 'INV-OFF',
              lines: taxableLines,
              payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
              linesTaxInclusive: false,
              receiptDate: DateTime(2026, 9, 25, 16, 0),
            )
            .then<Object?>((_) => null, onError: (Object e) => e);

        expect(error, isA<ZimraException>());
        final zimra = error! as ZimraException;
        expect(zimra.code, 'RCP030');
        expect(zimra.receiptPayload, isNotNull);

        // Journaled exactly once and local state advanced at signing time
        // (the receipt number is reserved by the sale).
        expect(d.offlineQueue, hasLength(1));
        expect(d.dayState.receiptCounter, 1);
        expect(d.dayState.receiptGlobalNo, 1);

        // Back online: the SAME payload is resubmitted — FDMS de-duplicates
        // it, so no second receipt number is consumed.
        api.failWith = null;
        final stored = zimra.receiptPayload!;
        final result = await d.resubmitReceipt(stored);

        expect(api.bodies.last, stored, reason: 'verbatim resubmission');
        expect(result.response.receiptId, 501);
        expect(result.qrData, d.qrDataForPayload(stored));
        expect(d.dayState.receiptCounter, 1, reason: 'no double increment');
      },
    );

    test('flush resubmits queued payloads in order', () async {
      final d = await openDevice();
      api.failWith = const SocketException('network down');
      try {
        await d.submitReceipt(
          currency: 'USD',
          invoiceNo: 'INV-1',
          lines: taxableLines,
          payments: [ReceiptPayment(moneyType: 'Cash', amount: 11500)],
          linesTaxInclusive: false,
        );
        fail('expected RCP030');
      } on ZimraException catch (e) {
        expect(e.code, 'RCP030');
      }
      expect(d.offlineQueue, hasLength(1));

      api.failWith = null;
      final flushed = await d.flushOfflineQueue();
      expect(flushed, hasLength(1));
      expect(d.offlineQueue, isEmpty);
    });
  });
}
