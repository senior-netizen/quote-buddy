import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra_models.dart';
import 'package:quoteflow/services/zimra/zimra_transport_io.dart';

void main() {
  test(
    'public transport sends the mandatory current FDMS model headers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      const identity = ZimraDeviceIdentity(
        deviceId: 1,
        serialNumber: 'TEST',
        modelName: 'Registered Model',
        modelVersion: '2.0',
      );
      final received = server.first.then((request) async {
        final headers = {
          'name': request.headers.value('DeviceModelName'),
          'version': request.headers.value('DeviceModelVersion'),
          'obsolete': request.headers.value('DeviceModelVersionNo'),
        };
        await request.drain<void>();
        request.response.write('{}');
        await request.response.close();
        return headers;
      });
      final response = await ZimraPublicTransport(
        baseUrl: 'http://127.0.0.1:${server.port}',
      ).post('/registration', body: {}, headers: identity.requestHeaders);
      expect(response.isSuccess, isTrue);
      expect(await received, {
        'name': 'Registered Model',
        'version': '2.0',
        'obsolete': null,
      });
    },
  );

  test('unknown persisted fiscal status cannot authorize a new fiscal day', () {
    expect(
      () => FiscalDayStatus.fromString('UnexpectedServerStatus'),
      throwsFormatException,
    );
    expect(
      FiscalDayStatus.fromString('fiscalDayClosed'),
      FiscalDayStatus.fiscalDayClosed,
    );
    for (final status in FiscalDayStatus.values) {
      expect(FiscalDayStatus.fromString(status.name), status);
    }
  });
}
