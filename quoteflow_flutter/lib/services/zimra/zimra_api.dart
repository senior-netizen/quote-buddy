/// HTTP contract shared by the mTLS (io) and proxy (web) FDMS transports.
///
/// Declared separately from the transports so tests can inject a scripted
/// [ZimraApi] instead of opening real mTLS connections.
library;

import 'zimra_response.dart';

abstract class ZimraApi {
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  });

  Future<ZimraHttpResponse> get(
    String path, {
    Map<String, String>? headers,
  });

  void close();
}
