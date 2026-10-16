import 'dart:convert';
import 'dart:io';
import 'billing_http_common.dart';
export 'billing_http_common.dart';

Future<Map<String, dynamic>> billingPost(
  String path,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final uri = billingEndpoint(path);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    return await (() async {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode(body));
      final response = await request.close();
      return decodeBillingResponse(
        response.statusCode,
        await response.transform(utf8.decoder).join(),
        path: path,
      );
    })().timeout(const Duration(seconds: 50));
  } finally {
    client.close(force: true);
  }
}
