// ZIMRA verification QR payload tests.
//
// The payload is NOT invented: it is built by
// ZimraFiscalDevice.buildVerificationQrData, a direct port of the FDMS QR
// construction implemented by this project:
//
//   {qrUrl}/{deviceId:0>10}{ddMMyyyy}{receiptGlobalNo:0>10}{md5_16}
//
// where md5_16 = first 16 hex chars of MD5 over the raw device-signature
// bytes (base64-decoded).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra.dart';

void main() {
  group('FDMS QR construction', () {
    test('known-answer: empty signature matches the RFC 1321 MD5 vector',
        () {
      // md5("") = d41d8cd98f00b204e9800998ecf8427e → first 16 hex chars.
      final payload = ZimraFiscalDevice.buildVerificationQrData(
        deviceId: 38513,
        receiptDate: DateTime(2026, 9, 25, 14, 30),
        receiptGlobalNo: 7,
        deviceSignatureBase64: base64Encode(<int>[]),
        qrBaseUrl: 'https://verify.zimra.example/',
      );

      expect(
        payload,
        'https://verify.zimra.example/'
        '0000038513'
        '25092026'
        '0000000007'
        'd41d8cd98f00b204',
      );
    });

    test('qrUrl without a trailing slash gets exactly one separator', () {
      final withSlash = ZimraFiscalDevice.buildVerificationQrData(
        deviceId: 38513,
        receiptDate: DateTime(2026, 9, 25),
        receiptGlobalNo: 1,
        deviceSignatureBase64: base64Encode(<int>[]),
        qrBaseUrl: 'https://verify.zimra.example/',
      );
      final withoutSlash = ZimraFiscalDevice.buildVerificationQrData(
        deviceId: 38513,
        receiptDate: DateTime(2026, 9, 25),
        receiptGlobalNo: 1,
        deviceSignatureBase64: base64Encode(<int>[]),
        qrBaseUrl: 'https://verify.zimra.example',
      );
      expect(withSlash, withoutSlash);
      expect(withSlash.split('example/').last.length, 10 + 8 + 10 + 16);
    });

    test('payload round-trips back to device, date, receipt no and MD5',
        () {
      final signatureBytes = utf8.encode('device-signature-bytes');
      final payload = ZimraFiscalDevice.buildVerificationQrData(
        deviceId: 38513,
        receiptDate: DateTime(2026, 1, 5, 8, 9),
        receiptGlobalNo: 1234567890,
        deviceSignatureBase64: base64Encode(signatureBytes),
        qrBaseUrl: 'https://verify.zimra.example/',
      );

      final match = RegExp(
        r'^(https://.+)/(\d{10})(\d{2})(\d{2})(\d{4})(\d{10})([0-9a-f]{16})$',
      ).firstMatch(payload);
      expect(match, isNotNull, reason: 'payload must match the FDMS layout');

      final base = match!.group(1)!;
      final deviceId = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final month = int.parse(match.group(4)!);
      final year = int.parse(match.group(5)!);
      final globalNo = int.parse(match.group(6)!);
      final md5_16 = match.group(7)!;

      expect(base, 'https://verify.zimra.example');
      expect(deviceId, 38513);
      expect(DateTime(year, month, day), DateTime(2026, 1, 5));
      expect(globalNo, 1234567890);
      expect(
        md5_16,
        md5.convert(signatureBytes).toString().substring(0, 16),
        reason: 'the 16-hex fragment must be MD5 of the raw signature bytes',
      );
    });

    test('device and receipt numbers are zero-padded to fixed width', () {
      final payload = ZimraFiscalDevice.buildVerificationQrData(
        deviceId: 7,
        receiptDate: DateTime(2026, 12, 31),
        receiptGlobalNo: 3,
        deviceSignatureBase64: base64Encode(<int>[]),
        qrBaseUrl: 'https://qr.example/',
      );
      expect(payload, contains('0000000007'));
      expect(payload, contains('31122026'));
      expect(payload, contains('0000000003'));
    });
  });
}
