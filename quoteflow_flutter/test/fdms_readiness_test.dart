import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/services/compliance/fdms_readiness.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

FdmsReadiness evidence() => FdmsReadiness(
  identity: {
    'deviceId': 123,
    'serialNumber': 'TEST',
    'modelName': 'Portal model',
    'modelVersion': '1',
  },
  metadata: {
    'tin': '2000000001',
    'businessName': 'Example Ltd',
    'branch': 'Harare',
    'supplier': 'Approved supplier',
    'orderNumber': 'ORDER-123',
    'region': 'SCO',
  },
);
void capture(
  FdmsReadiness c,
  String operation,
  Map<String, dynamic> response, {
  Map<String, dynamic> request = const {},
  int? day = 1,
  int status = 200,
}) => c.record(
  operation == 'GetStatus' || operation == 'GetConfig' ? 'GET' : 'POST',
  '/Device/v1/123/$operation',
  request,
  ZimraHttpResponse(
    statusCode: status,
    body: response,
    rawBody: jsonEncode(response),
  ),
  day,
);
Map<String, dynamic> receipt(
  String type,
  String currency,
  int no, {
  bool buyer = true,
  int lines = 2,
}) => {
  'receipt': {
    'receiptType': type,
    'receiptCurrency': currency,
    'receiptGlobalNo': no,
    'receiptLines': List.generate(
      lines,
      (_) => {'receiptLineType': 'Sale', 'receiptLineName': 'Example service'},
    ),
    'receiptTaxes': [
      {'taxID': 1, 'taxPercent': 15},
      {'taxID': 2, 'taxPercent': 0},
      {'taxID': 3},
    ],
    if (type != 'FiscalInvoice') 'creditDebitNote': {'receiptID': 1},
    if (buyer)
      'buyerData': {
        'buyerRegisterName': 'Customer Ltd',
        'buyerTIN': '2000000002',
        'buyerAddress': {'street': 'Park Road', 'city': 'Harare'},
      },
    'receiptDeviceSignature': {'hash': 'hash-$no', 'signature': 'signature'},
  },
};
void samples(FdmsReadiness c) {
  capture(c, 'GetConfig', {
    'applicableTaxes': [
      {'taxID': 1, 'taxPercent': 15},
      {'taxID': 2, 'taxPercent': 0},
      {'taxID': 3},
    ],
    'qrUrl': 'https://test.example/',
  });
  capture(c, 'OpenDay', {'fiscalDayNo': 1});
  int id = 0;
  for (final row in [
    ('FiscalInvoice', 'USD'),
    ('FiscalInvoice', 'ZWG'),
    ('CreditNote', 'USD'),
    ('DebitNote', 'USD'),
  ]) {
    id++;
    capture(c, 'SubmitReceipt', {
      'receiptID': id,
      'operationID': 'op-$id',
    }, request: receipt(row.$1, row.$2, id));
  }
}

void close(FdmsReadiness c) {
  capture(c, 'CloseDay', {'operationID': 'close'}, request: {'fiscalDayNo': 1});
  capture(c, 'GetStatus', {'fiscalDayStatus': 'FiscalDayClosed'});
}

class _Api implements ZimraApi {
  @override
  Future<ZimraHttpResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async => const ZimraHttpResponse(
    statusCode: 200,
    body: {'fiscalDayStatus': 'FiscalDayClosed'},
    rawBody: '{}',
  );
  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => get(path);
  @override
  void close() {}
}

void main() {
  test(
    'guide requirements require accepted USD/ZWG documents, notes, taxes, buyer data and a confirmed closed day',
    () {
      final c = evidence();
      samples(c);
      expect(c.ready, isFalse);
      capture(
        c,
        'CloseDay',
        {'operationID': 'close'},
        request: {'fiscalDayNo': 1},
      );
      capture(c, 'GetStatus', {'fiscalDayStatus': 'FiscalDayCloseInitiated'});
      expect(c.ready, isFalse);
      capture(c, 'GetStatus', {'fiscalDayStatus': 'FiscalDayClosed'});
      expect(c.ready, isTrue);
      expect(c.approvalRecorded, isFalse);
      c.metadata['approvalReference'] = 'ZIMRA-reference';
      expect(c.approvalRecorded, isTrue);
    },
  );
  test(
    'a closed status alone or a different day cannot complete day-close evidence',
    () {
      final c = evidence();
      samples(c);
      capture(c, 'GetStatus', {'fiscalDayStatus': 'FiscalDayClosed'}, day: 2);
      expect(c.completedDays, isEmpty);
      capture(c, 'CloseDay', {}, request: {'fiscalDayNo': 1});
      capture(c, 'GetStatus', {'fiscalDayStatus': 'FiscalDayCloseFailed'});
      expect(c.ready, isFalse);
    },
  );
  test(
    'validation errors, failed replies and unsupported currency cannot satisfy the checklist',
    () {
      final c = evidence();
      samples(c);
      close(c);
      c.events.removeWhere(
        (e) =>
            (e['request'] as Map)['receipt'] is Map &&
            ((e['request'] as Map)['receipt'] as Map)['receiptCurrency'] ==
                'ZWG',
      );
      capture(c, 'SubmitReceipt', {
        'receiptID': 9,
        'validationErrors': [
          {'validationErrorColor': 'Yellow'},
        ],
      }, request: receipt('FiscalInvoice', 'ZWG', 9));
      expect(c.ready, isFalse);
      capture(
        c,
        'SubmitReceipt',
        {'receiptID': 10},
        status: 400,
        request: receipt('FiscalInvoice', 'ZWG', 10),
      );
      expect(c.ready, isFalse);
      capture(c, 'SubmitReceipt', {
        'receiptID': 11,
      }, request: receipt('FiscalInvoice', 'ZWL', 11));
      expect(c.ready, isFalse);
    },
  );
  test(
    'changing applicable FDMS tax configuration requires new matching evidence',
    () {
      final c = evidence();
      samples(c);
      close(c);
      expect(c.ready, isTrue);
      capture(c, 'GetConfig', {
        'applicableTaxes': [
          {'taxID': 1, 'taxPercent': 15.5},
        ],
      });
      expect(c.ready, isFalse);
    },
  );
  test(
    'capture excludes secrets, deduplicates retries, binds the device, and exports a verifiable checksum',
    () {
      final c = evidence();
      samples(c);
      close(c);
      capture(
        c,
        'SubmitReceipt',
        {'receiptID': 20, 'privateKeyPem': 'secret', 'accessToken': 'private'},
        request: {
          ...receipt('FiscalInvoice', 'USD', 20),
          'activationKey': 'secret',
        },
      );
      final count = c.events.length;
      capture(
        c,
        'SubmitReceipt',
        {'receiptID': 20, 'privateKeyPem': 'secret', 'accessToken': 'private'},
        request: {
          ...receipt('FiscalInvoice', 'USD', 20),
          'activationKey': 'secret',
        },
      );
      expect(c.events.length, count);
      expect(jsonEncode(c.toJson()), isNot(contains('secret')));
      expect(
        () => c.record(
          'GET',
          '/Device/v1/999/GetStatus',
          null,
          const ZimraHttpResponse(statusCode: 200, body: {}, rawBody: '{}'),
          1,
        ),
        throwsFormatException,
      );
      final report = c.report();
      final checksum = report.remove('sha256');
      expect(checksum, evidenceDigest(report));
      expect(FdmsReadiness.fromJson(c.toJson()).ready, isTrue);
    },
  );
  test(
    'evidence storage failure cannot discard an accepted fiscal response',
    () async {
      var warned = false;
      final transport = EvidenceTransport(
        _Api(),
        (_, __, ___, ____) async =>
            throw const FileSystemException('disk full'),
        (_) {
          warned = true;
        },
      );
      final response = await transport.post(
        '/Device/v1/123/SubmitReceipt',
        body: {},
      );
      expect(response.statusCode, 200);
      expect(warned, isTrue);
    },
  );
  test('a reopened test day cannot reuse an earlier close confirmation', () {
    final c = evidence();
    samples(c);
    c.events.removeWhere(
      (e) =>
          (e['request'] as Map)['receipt'] is Map &&
          ((e['request'] as Map)['receipt'] as Map)['receiptCurrency'] == 'ZWG',
    );
    close(c);
    expect(c.ready, isFalse);
    capture(c, 'OpenDay', {'fiscalDayNo': 1});
    capture(c, 'SubmitReceipt', {
      'receiptID': 99,
    }, request: receipt('FiscalInvoice', 'ZWG', 99));
    expect(c.ready, isFalse);
    close(c);
    expect(c.ready, isTrue);
  });
  test(
    'provider persists response evidence and keeps taxpayer/order binding when the device is cleared',
    () async {
      final temp = await Directory.systemTemp.createTemp('readiness-capture-');
      Hive.init(temp.path);
      final box = await Hive.openBox('capture');
      await box.putAll({
        'zimra_identity': const ZimraDeviceIdentity(
          deviceId: 123,
          serialNumber: 'TEST',
        ).toJson(),
        'zimra_credentials': const ZimraCredentials(
          privateKeyPem: 'private-key-not-exported',
          certificatePem: 'certificate',
        ).toJson(),
      });
      final provider = ZimraProvider(box, transportFactory: () => _Api());
      await provider.init();
      try {
        await provider.refreshStatus();
        expect(provider.approvalCase!.events.single['operation'], 'GetStatus');
        expect(provider.approvalCase!.ready, isFalse);
        await provider.saveApprovalMetadata(evidence().metadata);
        await expectLater(
          provider.saveApprovalMetadata({
            ...evidence().metadata,
            'tin': '2000000002',
          }),
          throwsFormatException,
        );
        await provider.clearDevice();
        expect(provider.approvalCase!.metadata['orderNumber'], 'ORDER-123');
        expect(
          jsonEncode(provider.approvalCase!.toJson()),
          isNot(contains('private-key-not-exported')),
        );
        final approved = evidence();
        samples(approved);
        close(approved);
        approved.metadata['approvalReference'] = 'ZIMRA-reference';
        await box.put('fdms_readiness_v1:123:TEST', approved.toJson());
        await expectLater(
          provider.registerDevice(
            device: const ZimraDeviceIdentity(
              deviceId: 456,
              serialNumber: 'LIVE',
            ),
            activationKey: '12345678',
            environment: ZimraEnvironment.production,
            businessTin: '2000000002',
            credentialsIssuedAt: DateTime.now(),
          ),
          throwsA(
            isA<ZimraException>().having(
              (e) => e.code,
              'code',
              'APPROVAL_REQUIRED',
            ),
          ),
        );
      } finally {
        provider.dispose();
        await box.close();
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'provider rejects expired activation and production without completed taxpayer evidence before network access',
    () async {
      final temp = await Directory.systemTemp.createTemp('readiness-provider-');
      Hive.init(temp.path);
      final box = await Hive.openBox('device');
      final provider = ZimraProvider(box);
      await provider.init();
      try {
        const device = ZimraDeviceIdentity(deviceId: 123, serialNumber: 'TEST');
        await expectLater(
          provider.registerDevice(
            device: device,
            activationKey: '12345678',
            credentialsIssuedAt: DateTime.now().subtract(
              const Duration(hours: 25),
            ),
          ),
          throwsA(
            isA<ZimraException>().having(
              (e) => e.code,
              'code',
              'ACTIVATION_EXPIRED',
            ),
          ),
        );
        await expectLater(
          provider.registerDevice(
            device: device,
            activationKey: '12345678',
            environment: ZimraEnvironment.production,
            businessTin: '2000000001',
            credentialsIssuedAt: DateTime.now(),
          ),
          throwsA(
            isA<ZimraException>().having(
              (e) => e.code,
              'code',
              'APPROVAL_REQUIRED',
            ),
          ),
        );
      } finally {
        provider.dispose();
        await box.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
