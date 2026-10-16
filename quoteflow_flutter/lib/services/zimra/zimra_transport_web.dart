// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'zimra_api.dart';
import 'zimra_response.dart';

export 'zimra_response.dart';

class ZimraTransport implements ZimraApi {
  final String baseUrl;
  final String certificatePem;
  final String privateKeyPem;
  final Map<String, String> defaultHeaders;

  ZimraTransport({
    required this.baseUrl,
    required this.certificatePem,
    required this.privateKeyPem,
    this.defaultHeaders = const {},
  });

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) {
    return _proxyRequest(
      baseUrl: baseUrl,
      method: 'POST',
      path: path,
      body: body,
      headers: {...defaultHeaders, ...?headers},
      certificatePem: certificatePem,
      privateKeyPem: privateKeyPem,
    );
  }

  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) {
    return _proxyRequest(
      baseUrl: baseUrl,
      method: 'GET',
      path: path,
      headers: {...defaultHeaders, ...?headers},
      certificatePem: certificatePem,
      privateKeyPem: privateKeyPem,
    );
  }

  @override
  void close() {}
}

class ZimraPublicTransport {
  final String baseUrl;

  ZimraPublicTransport({required this.baseUrl});

  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) {
    return _proxyRequest(
      baseUrl: baseUrl,
      method: 'POST',
      path: path,
      body: body,
      headers: headers ?? const {},
    );
  }
}

Future<ZimraHttpResponse> _proxyRequest({
  required String baseUrl,
  required String method,
  required String path,
  required Map<String, String> headers,
  Map<String, dynamic>? body,
  String? certificatePem,
  String? privateKeyPem,
}) async {
  const configuredProxy = String.fromEnvironment('ZIMRA_WEB_PROXY_URL');
  final proxyUrl = configuredProxy.isEmpty ? '/api/zimra' : configuredProxy;

  try {
    final response = await html.HttpRequest.request(
      proxyUrl,
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'baseUrl': baseUrl,
        'method': method,
        'path': path,
        'headers': headers,
        if (body != null) 'body': body,
        if (certificatePem != null) 'certificatePem': certificatePem,
        if (privateKeyPem != null) 'privateKeyPem': privateKeyPem,
      }),
    );
    final envelope =
        jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
    final rawBody = envelope['rawBody'] as String? ?? '';
    Map<String, dynamic> parsedBody = {};
    if (rawBody.isNotEmpty) {
      try {
        parsedBody = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {}
    }
    return ZimraHttpResponse(
      statusCode: (envelope['statusCode'] as num?)?.toInt() ?? 502,
      body: parsedBody,
      rawBody: rawBody,
    );
  } catch (error) {
    return ZimraHttpResponse(
      statusCode: 503,
      body: const {},
      rawBody: jsonEncode({
        'title': 'ZIMRA web gateway unavailable',
        'detail': '$error',
      }),
    );
  }
}
