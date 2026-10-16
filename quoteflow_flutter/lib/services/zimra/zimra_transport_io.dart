/// mTLS HTTP transport for ZIMRA FDMS.
library;

///
/// Uses dart:io HttpClient with client certificates for mutual TLS.
/// All requests to FDMS require mTLS — the device certificate proves identity.
import 'dart:convert';
import 'dart:io';

import 'zimra_api.dart';
import 'zimra_response.dart';

export 'zimra_response.dart';

/// mTLS-capable HTTP client for FDMS.
class ZimraTransport implements ZimraApi {
  final String baseUrl;
  final String certificatePem;
  final String privateKeyPem;
  final Map<String, String> defaultHeaders;

  late final SecurityContext _securityContext;
  late final HttpClient _httpClient;

  ZimraTransport({
    required this.baseUrl,
    required this.certificatePem,
    required this.privateKeyPem,
    this.defaultHeaders = const {},
  }) {
    _securityContext = SecurityContext(withTrustedRoots: true);
    // Add the device certificate for mTLS
    _securityContext.useCertificateChainBytes(utf8.encode(certificatePem));
    _securityContext.usePrivateKeyBytes(utf8.encode(privateKeyPem));

    _httpClient = HttpClient(context: _securityContext);
    _httpClient.connectionTimeout = const Duration(seconds: 30);
    _httpClient.idleTimeout = const Duration(minutes: 5);
  }

  /// POST JSON to FDMS.
  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.add('Accept', 'application/json');
    defaultHeaders.forEach((k, v) => request.headers.set(k, v));
    headers?.forEach((k, v) => request.headers.set(k, v));
    request.write(jsonEncode(body));

    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();
    Map<String, dynamic> parsedBody = {};
    try {
      parsedBody = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {
      // Non-JSON response
    }

    return ZimraHttpResponse(
      statusCode: response.statusCode,
      body: parsedBody,
      rawBody: rawBody,
    );
  }

  /// GET from FDMS.
  @override
  Future<ZimraHttpResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _httpClient.getUrl(uri);
    request.headers.add('Accept', 'application/json');
    defaultHeaders.forEach((k, v) => request.headers.set(k, v));
    headers?.forEach((k, v) => request.headers.set(k, v));

    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();
    Map<String, dynamic> parsedBody = {};
    try {
      parsedBody = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {}

    return ZimraHttpResponse(
      statusCode: response.statusCode,
      body: parsedBody,
      rawBody: rawBody,
    );
  }

  @override
  void close() {
    _httpClient.close(force: true);
  }
}

/// Simple HTTP client for unauthenticated requests (device registration).
class ZimraPublicTransport {
  final String baseUrl;

  ZimraPublicTransport({required this.baseUrl});

  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();

    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.add('Accept', 'application/json');
      headers?.forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(body));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();
      Map<String, dynamic> parsedBody = {};
      try {
        parsedBody = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {}

      return ZimraHttpResponse(
        statusCode: response.statusCode,
        body: parsedBody,
        rawBody: rawBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
