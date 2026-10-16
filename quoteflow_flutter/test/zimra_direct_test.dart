// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

// This diagnostic script sends a request to the live ZIMRA test API. Keep it
// opt-in so it cannot make network calls as part of `flutter test`.
const _runLiveTest = bool.fromEnvironment('RUN_ZIMRA_LIVE_TEST');

void main() {
  test(
    'ZIMRA direct registration against the test environment',
    _runDirectTest,
    skip: _runLiveTest ? false : 'Set RUN_ZIMRA_LIVE_TEST=true to run live.',
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Future<void> _runDirectTest() async {
  const deviceId = int.fromEnvironment('ZIMRA_DEVICE_ID');
  const serialNumber = String.fromEnvironment('ZIMRA_SERIAL');
  const activationKey = String.fromEnvironment('ZIMRA_ACTIVATION_KEY');
  if (deviceId <= 0 || serialNumber.isEmpty || activationKey.isEmpty) {
    throw StateError(
      'Provide ZIMRA_DEVICE_ID, ZIMRA_SERIAL, and ZIMRA_ACTIVATION_KEY.',
    );
  }
  final device = ZimraDeviceIdentity(
    deviceId: deviceId,
    serialNumber: serialNumber,
    modelName: const String.fromEnvironment(
      'ZIMRA_MODEL_NAME',
      defaultValue: 'Virtual Server',
    ),
    modelVersion: const String.fromEnvironment(
      'ZIMRA_MODEL_VERSION',
      defaultValue: 'v1',
    ),
  );

  final keyPair = generateKeyPair();
  final csrPem = buildCsrPem(
    privateKey: keyPair.privateKey,
    publicKey: keyPair.publicKey,
    commonName: device.commonName,
  );

  print('CSR PEM:');
  print(csrPem);
  print('');
  print('CSR first line: ${csrPem.split('\n').first}');
  print('CSR base64 part (no headers):');
  final b64 = csrPem
      .replaceAll('-----BEGIN CERTIFICATE REQUEST-----', '')
      .replaceAll('-----END CERTIFICATE REQUEST-----', '')
      .replaceAll('\n', '')
      .replaceAll('\r', '');
  print('B64 length: ${b64.length}');
  print('B64 first 80: ${b64.substring(0, min(80, b64.length))}');

  // Manual HTTP POST
  final client = HttpClient();

  try {
    final uri = Uri.parse(
      'https://fdmsapitest.zimra.co.zw/Public/v1/$deviceId/RegisterDevice',
    );
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.add('Accept', 'application/json');
    request.headers.set('DeviceModelName', device.modelName);
    request.headers.set('DeviceModelVersion', device.modelVersion);

    final body = jsonEncode({
      'activationKey': activationKey,
      'certificateRequest': csrPem,
    });

    print('\nSending request...');
    print('Body length: ${body.length}');
    request.write(body);

    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();

    print('\nResponse status: ${response.statusCode}');
    print('Response body: $rawBody');
    expect(response.statusCode, HttpStatus.ok, reason: rawBody);
  } finally {
    client.close(force: true);
  }
}

int min(int a, int b) => a < b ? a : b;
