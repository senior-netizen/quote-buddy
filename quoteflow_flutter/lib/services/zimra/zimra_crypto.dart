/// ECDSA P-256 cryptographic operations for ZIMRA FDMS.
///
/// Handles key generation and DER signing. PEM encoding uses raw key bytes
/// with standard headers (PKCS#8 compatible for FDMS).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

// ---------------------------------------------------------------------------
// Key generation
// ---------------------------------------------------------------------------

class ZimraKeyPair {
  final ECPublicKey publicKey;
  final ECPrivateKey privateKey;

  const ZimraKeyPair({required this.publicKey, required this.privateKey});
}

/// Generate an ECDSA P-256 key pair.
ZimraKeyPair generateKeyPair() {
  final domainParams = ECCurve_secp256r1();
  final secureRandom = FortunaRandom();

  final seedSource = Random.secure();
  final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  final keyGenerator = ECKeyGenerator();
  keyGenerator.init(
    ParametersWithRandom(ECKeyGeneratorParameters(domainParams), secureRandom),
  );
  final keyPair = keyGenerator.generateKeyPair();

  return ZimraKeyPair(
    publicKey: keyPair.publicKey as ECPublicKey,
    privateKey: keyPair.privateKey as ECPrivateKey,
  );
}

// ---------------------------------------------------------------------------
// PEM encoding (raw key bytes with standard headers)
// ---------------------------------------------------------------------------

/// Encode EC private key as PEM.
///
/// Uses raw key bytes (d value) with PKCS#8-style header.
/// FDMS accepts this format for mTLS client certificates.
String encodePrivateKeyPem(ECPrivateKey key) {
  final d = key.d!;
  final dBytes = _bigIntToBytes(d);

  // Pad to 32 bytes (P-256 key size)
  final padded = Uint8List(32)..setAll(32 - dBytes.length, dBytes);

  // Build minimal PKCS#8 wrapper
  final pkcs8 = _buildPkcs8PrivateKey(padded);
  return _pemEncode('PRIVATE KEY', pkcs8);
}

/// Encode EC public key as PEM (uncompressed point).
String encodePublicKeyPem(ECPublicKey key) {
  final q = key.Q!;
  final pubBytes = _encodeUncompressedPoint(q);

  // Build minimal SPKI wrapper
  final spki = _buildSpkiPublicKey(pubBytes);
  return _pemEncode('PUBLIC KEY', spki);
}

/// Decode a PEM-encoded EC private key.
ECPrivateKey decodePrivateKeyPem(String pem) {
  final der = _pemDecode(pem);

  // Try to extract d from PKCS#8 wrapper
  final dBytes = _extractPrivateKeyFromPkcs8(der);
  final d = _bytesToBigInt(dBytes);

  final domain = ECCurve_secp256r1();
  return ECPrivateKey(d, domain);
}

/// Decode a PEM-encoded EC public key.
ECPublicKey decodePublicKeyPem(String pem) {
  final der = _pemDecode(pem);

  // Extract uncompressed point from SPKI
  final pubBytes = _extractPublicKeyFromSpki(der);
  final domain = ECCurve_secp256r1();

  final q = domain.curve.decodePoint(pubBytes);
  return ECPublicKey(q, domain);
}

// ---------------------------------------------------------------------------
// CSR generation (simplified — builds raw ASN.1 manually)
// ---------------------------------------------------------------------------

/// Build a CSR with ZIMRA's required subject CN format.
String buildCsrPem({
  required ECPrivateKey privateKey,
  required ECPublicKey publicKey,
  required String commonName,
}) {
  // Build the CRI (certificationRequestInfo) — the part that gets signed
  final subjectDer = _buildCsrSubject(commonName);
  final pubKeyDer = _buildCsrPublicKey(publicKey);

  // CRI = SEQUENCE { version, subject, SPKI, attributes [0] }
  final emptyAttributes = Uint8List(0);
  final certReqInfo = _buildDerSequence([
    _buildDerInteger(Uint8List.fromList([0x00])),
    subjectDer,
    pubKeyDer,
    _buildDerTag(0xA0, emptyAttributes),
  ]);

  // Sign the raw CRI bytes (not a string representation)
  final signature = _signRawBytes(certReqInfo, privateKey);

  // Build the full CSR
  final sigAlgo = _buildDerSequence([_sha256WithEcdsaOid]);
  final csrDer = _buildDerSequence([
    certReqInfo,
    sigAlgo,
    _buildDerBitString(signature),
  ]);

  return _pemEncode('CERTIFICATE REQUEST', csrDer);
}

// ---------------------------------------------------------------------------
// DER signing
// ---------------------------------------------------------------------------

/// Sign [data] with ECDSA P-256 and return the signature in ASN.1 DER format.
Uint8List signDer(String data, ECPrivateKey privateKey) {
  return _signRawBytes(Uint8List.fromList(utf8.encode(data)), privateKey);
}

/// Sign raw bytes with ECDSA P-256 and return DER-encoded signature.
/// The caller wraps this in a BIT STRING (matching the SDK's p1363ToDer).
Uint8List _signRawBytes(Uint8List data, ECPrivateKey privateKey) {
  final secureRandom = FortunaRandom();
  final seedSource = Random.secure();
  final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  final signer = ECDSASigner(SHA256Digest());
  signer.init(
    true,
    ParametersWithRandom(PrivateKeyParameter(privateKey), secureRandom),
  );
  // ECDSASigner hashes the input itself. Prehashing here would produce an
  // invalid ecdsa-with-SHA256 signature over SHA256(SHA256(data)).
  final sig = signer.generateSignature(data) as ECSignature;

  // Return DER-encoded signature (same as SDK's p1363ToDer)
  return _ecdsaSignatureToDer(sig.r, sig.s);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _ecdsaSignatureToDer(BigInt r, BigInt s) {
  final rBytes = _bigIntToBytes(r);
  final sBytes = _bigIntToBytes(s);

  final rEncoded = rBytes[0] & 0x80 != 0
      ? Uint8List.fromList([0x00, ...rBytes])
      : rBytes;
  final sEncoded = sBytes[0] & 0x80 != 0
      ? Uint8List.fromList([0x00, ...sBytes])
      : sBytes;

  return _buildDerSequence([
    _buildDerInteger(rEncoded),
    _buildDerInteger(sEncoded),
  ]);
}

Uint8List _bigIntToBytes(BigInt big) {
  final hex = big.toRadixString(16);
  final padded = hex.length.isEven ? hex : '0$hex';
  final bytes = <int>[];
  for (var i = 0; i < padded.length; i += 2) {
    bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _encodeUncompressedPoint(ECPoint point) {
  final x = _bigIntToBytes(point.x!.toBigInteger()!);
  final y = _bigIntToBytes(point.y!.toBigInteger()!);

  final xPadded = Uint8List(32)..setAll(32 - x.length, x);
  final yPadded = Uint8List(32)..setAll(32 - y.length, y);

  return Uint8List.fromList([0x04, ...xPadded, ...yPadded]);
}

// ---------------------------------------------------------------------------
// Minimal DER builders
// ---------------------------------------------------------------------------

Uint8List _buildDerLength(int length) {
  if (length < 0x80) return Uint8List.fromList([length]);
  if (length < 0x100) return Uint8List.fromList([0x81, length]);
  return Uint8List.fromList([0x82, (length >> 8) & 0xFF, length & 0xFF]);
}

Uint8List _buildDerTag(int tag, Uint8List content) {
  return Uint8List.fromList([
    tag,
    ..._buildDerLength(content.length),
    ...content,
  ]);
}

Uint8List _buildDerInteger(Uint8List value) {
  return _buildDerTag(0x02, value);
}

Uint8List _buildDerSequence(List<Uint8List> items) {
  final all = _concatBytes(items);
  return _buildDerTag(0x30, all);
}

Uint8List _buildDerOctetString(Uint8List content) {
  return _buildDerTag(0x04, content);
}

Uint8List _buildDerBitString(Uint8List content) {
  // BIT STRING with 0 unused bits
  return _buildDerTag(0x03, Uint8List.fromList([0x00, ...content]));
}

Uint8List _buildDerOid(List<int> oidComponents) {
  final bytes = <int>[];
  bytes.add(oidComponents[0] * 40 + oidComponents[1]);
  for (var i = 2; i < oidComponents.length; i++) {
    var value = oidComponents[i];
    if (value < 0x80) {
      bytes.add(value);
    } else {
      final temp = <int>[];
      while (value > 0) {
        temp.insert(0, value & 0x7F);
        value >>= 7;
      }
      for (var j = 0; j < temp.length; j++) {
        bytes.add(temp[j] | (j < temp.length - 1 ? 0x80 : 0));
      }
    }
  }
  return _buildDerTag(0x06, Uint8List.fromList(bytes));
}

Uint8List _concatBytes(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (s, p) => s + p.length);
  final result = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    result.setAll(offset, part);
    offset += part.length;
  }
  return result;
}

// ---------------------------------------------------------------------------
// PKCS#8 / SPKI wrappers (minimal, P-256 specific)
// ---------------------------------------------------------------------------

/// secp256r1 OID: 1.2.840.10045.3.1.7
final _secp256r1Oid = _buildDerOid([1, 2, 840, 10045, 3, 1, 7]);
final _sha256WithEcdsaOid = _buildDerOid([1, 2, 840, 10045, 4, 3, 2]);
final _ecPublicKeyOid = _buildDerOid([1, 2, 840, 10045, 2, 1]);

Uint8List _buildPkcs8PrivateKey(Uint8List dBytes) {
  // ECPrivateKey structure
  final ecPrivateKey = _buildDerSequence([
    _buildDerInteger(Uint8List.fromList([0x01])), // version 1
    _buildDerOctetString(dBytes),
    _buildDerTag(0xA0, _secp256r1Oid), // explicit curve OID
  ]);

  // AlgorithmIdentifier
  final algoId = _buildDerSequence([_ecPublicKeyOid, _secp256r1Oid]);

  // PKCS#8 PrivateKeyInfo
  return _buildDerSequence([
    _buildDerInteger(Uint8List.fromList([0x00])), // version 0
    algoId,
    _buildDerOctetString(ecPrivateKey),
  ]);
}

Uint8List _buildSpkiPublicKey(Uint8List uncompressedPoint) {
  final algoId = _buildDerSequence([_ecPublicKeyOid, _secp256r1Oid]);

  return _buildDerSequence([algoId, _buildDerBitString(uncompressedPoint)]);
}

Uint8List _buildCsrSubject(String commonName) {
  // CN attribute: OID 2.5.4.3 + UTF8String
  final cnAttr = _buildDerSequence([
    _buildDerOid([2, 5, 4, 3]),
    _buildDerTag(0x0C, Uint8List.fromList(utf8.encode(commonName))),
  ]);

  // RDN is a SET (tag 0x31), not a SEQUENCE
  final rdn = _buildDerTag(0x31, cnAttr);
  // Subject is SEQUENCE of SET of SEQUENCE
  return _buildDerSequence([rdn]);
}

Uint8List _buildCsrPublicKey(ECPublicKey publicKey) {
  return _buildSpkiPublicKey(_encodeUncompressedPoint(publicKey.Q!));
}

Uint8List _extractPrivateKeyFromPkcs8(Uint8List der) {
  final pkcs8 = ASN1Parser(der).nextObject() as ASN1Sequence;
  final privateKey = pkcs8.elements![2] as ASN1OctetString;
  final ecPrivateKey =
      ASN1Parser(privateKey.octets).nextObject() as ASN1Sequence;
  return (ecPrivateKey.elements![1] as ASN1OctetString).octets!;
}

Uint8List _extractPublicKeyFromSpki(Uint8List der) {
  final spki = ASN1Parser(der).nextObject() as ASN1Sequence;
  final publicKey = spki.elements![1] as ASN1BitString;
  return Uint8List.fromList(publicKey.stringValues!);
}

// ---------------------------------------------------------------------------
// PEM encoding/decoding
// ---------------------------------------------------------------------------

String _pemEncode(String label, Uint8List der) {
  final b64 = base64Encode(der);
  final lines = <String>[];
  for (var i = 0; i < b64.length; i += 64) {
    lines.add(b64.substring(i, min(i + 64, b64.length)));
  }
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----';
}

Uint8List _pemDecode(String pem) {
  final stripped = pem
      .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
      .replaceAll(RegExp(r'-----END [^-]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  return base64Decode(stripped);
}
