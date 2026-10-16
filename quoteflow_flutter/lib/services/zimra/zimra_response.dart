/// Shared FDMS HTTP response wrapper.
///
/// Lives in its own file (instead of being duplicated per transport) so the
/// [ZimraApi] interface and both transports agree on one type on every
/// platform.
library;

class ZimraHttpResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  final String rawBody;

  const ZimraHttpResponse({
    required this.statusCode,
    required this.body,
    required this.rawBody,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
