import 'dart:convert';

class BillingClientException implements Exception {
  final int status;
  final String message;
  const BillingClientException(this.status, this.message);
  @override
  String toString() => message;
}

Uri billingEndpoint(String path, {String? origin}) {
  const base = String.fromEnvironment('BILLING_SERVER_URL');
  if (base.isEmpty && origin == null) {
    throw const BillingClientException(
      503,
      'Credit payments are not configured for this app yet.',
    );
  }
  final uri = Uri.parse(base.isEmpty ? origin! : base);
  final local = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if ((uri.scheme != 'https' &&
          !(local &&
              uri.scheme == 'http' &&
              !const bool.fromEnvironment('dart.vm.product'))) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const BillingClientException(
      503,
      'The credit server must use a secure HTTPS address.',
    );
  }
  return uri.resolve(path);
}

Map<String, dynamic> decodeBillingResponse(
  int status,
  String raw, {
  String? path,
}) {
  Map<String, dynamic> body;
  try {
    body = Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    if (path == '/api/onboarding' && (status == 404 || status == 405)) {
      throw BillingClientException(
        status,
        'Business account registration and sign-in are not available on the server yet. Please contact QuoteFlow support. You can continue working offline.',
      );
    }
    if (status >= 500) {
      throw BillingClientException(
        status,
        'The credit server is temporarily unavailable. Please try again later.',
      );
    }
    throw const BillingClientException(
      502,
      'The credit server returned an invalid response.',
    );
  }
  if (status < 200 || status >= 300) {
    throw BillingClientException(
      status,
      body['error'] is String
          ? body['error'] as String
          : 'The credit request failed.',
    );
  }
  return body;
}
