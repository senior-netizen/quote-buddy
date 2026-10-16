import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quoteflow/services/zimra/zimra_crypto.dart';

void main() {
  test('CSR has a valid SHA-256 signature and the device common name', () {
    final keys = generateKeyPair();
    const commonName = 'ZIMRA-TEST-SERIAL-0000000123';
    final csr = buildCsrPem(
      privateKey: keys.privateKey,
      publicKey: keys.publicKey,
      commonName: commonName,
    );

    final parsed = X509Utils.csrFromPem(csr);
    expect(parsed.certificationRequestInfo!.subject!['2.5.4.3'], commonName);
    expect(parsed.signatureAlgorithm, '1.2.840.10045.4.3.2');
    expect(X509Utils.checkCsrSignature(csr), isTrue);
  });

  test('receipt signature verifies against the original bytes once hashed', () {
    final keys = generateKeyPair();
    const canonical = '123FiscalInvoiceUSD12026-09-16T12:00:001000';
    final signature = CryptoUtils.ecSignatureFromDerBytes(
      signDer(canonical, keys.privateKey),
    );
    final publicKey = CryptoUtils.ecPublicKeyFromPem(
      encodePublicKeyPem(keys.publicKey),
    );

    expect(
      CryptoUtils.ecVerify(
        publicKey,
        Uint8List.fromList(utf8.encode(canonical)),
        signature,
        algorithm: 'SHA-256/ECDSA',
      ),
      isTrue,
    );
    expect(
      CryptoUtils.ecVerify(
        publicKey,
        Uint8List.fromList(utf8.encode('${canonical}0')),
        signature,
        algorithm: 'SHA-256/ECDSA',
      ),
      isFalse,
    );
  });

  test('private PEM restores the original signing key', () {
    final keys = generateKeyPair();
    final pem = encodePrivateKeyPem(keys.privateKey);
    final restored = decodePrivateKeyPem(pem);

    expect(restored.d, keys.privateKey.d);
    expect(CryptoUtils.ecPrivateKeyFromPem(pem).d, restored.d);
  });

  test('public PEM restores the original elliptic curve point', () {
    final keys = generateKeyPair();
    final pem = encodePublicKeyPem(keys.publicKey);
    final restored = decodePublicKeyPem(pem);
    final independent = CryptoUtils.ecPublicKeyFromPem(pem);

    expect(restored.Q, keys.publicKey.Q);
    expect(restored.Q, independent.Q);
  });
}
