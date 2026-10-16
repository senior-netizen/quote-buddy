import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class BillingError implements Exception {
  final int status;
  final String message;
  const BillingError(this.status, this.message);
}

bool constantTimeEqual(String a, String b) {
  final left = utf8.encode(a), right = utf8.encode(b);
  var difference = left.length ^ right.length;
  for (var i = 0; i < left.length; i++) {
    difference |= left[i] ^ (i < right.length ? right[i] : 0);
  }
  return difference == 0;
}

String paynowHash(Map<String, String> fields, String key) => sha512
    .convert(
      utf8.encode(
        fields.entries
                .where((e) => e.key.toLowerCase() != 'hash')
                .map((e) => e.value)
                .join() +
            key,
      ),
    )
    .toString()
    .toUpperCase();

Map<String, String> decodePaynow(String raw, String key) {
  final fields = <String, String>{};
  for (final part in raw.split('&')) {
    final index = part.indexOf('=');
    if (index < 1) throw const BillingError(400, 'Invalid payment message.');
    final name = Uri.decodeQueryComponent(
      part.substring(0, index),
    ).toLowerCase();
    if (fields.containsKey(name)) {
      throw const BillingError(400, 'Duplicate payment field.');
    }
    fields[name] = Uri.decodeQueryComponent(part.substring(index + 1));
  }
  final signature = fields['hash'] ?? '';
  if (!RegExp(r'^[a-fA-F0-9]{128}$').hasMatch(signature) ||
      !constantTimeEqual(signature.toUpperCase(), paynowHash(fields, key))) {
    throw const BillingError(400, 'Payment signature verification failed.');
  }
  return fields;
}

Uri trustedPaynowUrl(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'www.paynow.co.zw' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      uri.fragment.isNotEmpty) {
    throw const BillingError(502, 'Untrusted payment URL.');
  }
  return uri;
}

abstract interface class PaynowGateway {
  Map<String, String> decode(String raw);
  Future<Map<String, String>> initiate(Map<String, String> fields);
  Future<Map<String, String>> poll(String url);
}

class PaynowClient implements PaynowGateway {
  final String key;
  final String integrationId;
  PaynowClient({required this.key, required this.integrationId});

  @override
  Map<String, String> decode(String raw) => decodePaynow(raw, key);

  Future<Map<String, String>> _post(Uri uri, Map<String, String> fields) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      return await (() async {
        final request = await client.postUrl(uri);
        request.followRedirects = false;
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(
          fields.entries
              .map(
                (e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
              )
              .join('&'),
        );
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            throw const BillingError(502, 'Payment response is too large.');
          }
        }
        if (response.statusCode != 200) {
          throw const BillingError(502, 'Payment provider is unavailable.');
        }
        return decode(utf8.decode(bytes));
      })().timeout(const Duration(seconds: 30));
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, String>> initiate(Map<String, String> fields) {
    final message = <String, String>{
      'id': integrationId,
      ...fields,
      'status': 'Message',
    };
    message['hash'] = paynowHash(message, key);
    return _post(
      Uri.https(
        'www.paynow.co.zw',
        fields['method'] == 'ecocash'
            ? '/interface/remotetransaction'
            : '/interface/initiatetransaction',
      ),
      message,
    );
  }

  @override
  Future<Map<String, String>> poll(String url) {
    final uri = trustedPaynowUrl(url);
    if (uri.path.toLowerCase() != '/interface/checkpayment/' &&
        uri.path.toLowerCase() != '/interface/checkpayment') {
      throw const BillingError(502, 'Invalid payment status URL.');
    }
    return _post(uri, {});
  }
}
