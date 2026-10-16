import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quoteflow/providers/zimra_provider.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

class _Api implements ZimraApi {
  Completer<ZimraHttpResponse> response = Completer();
  int calls = 0;
  int closes = 0;
  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) {
    calls++;
    return response.future;
  }

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => get(path);
  @override
  void close() => closes++;
}

const _config = ZimraHttpResponse(
  statusCode: 200,
  body: {
    'qrUrl': 'https://verify.example/',
    'applicableTaxes': [
      {'taxID': 1, 'taxPercent': 15, 'taxName': 'Standard'},
    ],
  },
  rawBody: '{}',
);

void main() {
  late Directory directory;
  late Box box;
  late _Api api;
  late ZimraProvider provider;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zimra-refresh-');
    Hive.init(directory.path);
    box = await Hive.openBox('refresh');
    await box.putAll({
      'zimra_identity': const ZimraDeviceIdentity(
        deviceId: 38513,
        serialNumber: 'TEST',
      ).toJson(),
      'zimra_credentials': const ZimraCredentials(
        privateKeyPem: '',
        certificatePem: '',
      ).toJson(),
      'zimra_day_state': FiscalDayState(
        status: FiscalDayStatus.fiscalDayOpened,
        receiptCounter: 3,
        receiptGlobalNo: 42,
      ).toJson(),
    });
    api = _Api();
    provider = ZimraProvider(box, transportFactory: () => api);
    await provider.init();
  });
  tearDown(() async {
    provider.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'refresh exposes busy state, coalesces taps, persists results and closes',
    () async {
      final first = provider.fetchConfig();
      final second = provider.fetchConfig();
      expect(identical(first, second), isTrue);
      expect(provider.isFetchingConfig, isTrue);
      expect(provider.isLoading, isTrue);
      api.response.complete(_config);
      expect(await first, isNotNull);
      expect(api.calls, 1);
      expect(api.closes, 1);
      expect(provider.isFetchingConfig, isFalse);
      expect(provider.configFetchedAt, isNotNull);
      final restored = ZimraProvider(box);
      await restored.init();
      expect(restored.config!.qrUrl, _config.body['qrUrl']);
      expect(restored.configFetchedAt, provider.configFetchedAt);
      restored.dispose();
    },
  );

  test(
    'failure preserves cached configuration; successful retry clears error',
    () async {
      api.response.complete(_config);
      await provider.fetchConfig();
      final fetchedAt = provider.configFetchedAt;
      api.response = Completer();
      final failed = provider.fetchConfig();
      await Future<void>.delayed(Duration.zero);
      api.response.completeError(const SocketException('offline'));
      expect(await failed, isNull);
      expect(provider.error, contains('offline'));
      expect(provider.configFetchedAt, fetchedAt);
      expect(provider.config!.qrUrl, _config.body['qrUrl']);
      api.response = Completer();
      final retry = provider.fetchConfig();
      expect(provider.error, isNull);
      api.response.complete(_config);
      await retry;
      expect(provider.error, isNull);
      expect(api.closes, 3);
    },
  );

  test(
    'restart restores day status and clearing resets timestamps and counts',
    () async {
      expect(provider.status, FiscalDayStatus.fiscalDayOpened);
      expect(provider.isOpen, isTrue);
      expect(provider.receiptCount, 3);
      api.response.complete(_config);
      await provider.fetchConfig();
      await provider.clearDevice();
      expect(provider.isRegistered, isFalse);
      expect(provider.configFetchedAt, isNull);
      expect(provider.receiptCount, 0);
      expect(provider.globalReceiptCount, 0);
      expect(box.get('zimra_config_fetched_at'), isNull);
    },
  );

  test(
    'unrecognized stored status prevents opening a day with reset counters',
    () async {
      await box.put('zimra_day_state', {
        ...FiscalDayState(receiptGlobalNo: 42).toJson(),
        'status': 'UnexpectedStatus',
      });
      final restored = ZimraProvider(box, transportFactory: () => api);
      await restored.init();
      addTearDown(restored.dispose);
      expect(restored.error, contains('Failed to load ZIMRA state'));
      await expectLater(restored.openDay(), throwsA(isA<ZimraException>()));
      expect(api.calls, 0);
      expect((box.get('zimra_day_state') as Map)['receiptGlobalNo'], 42);
    },
  );
}
