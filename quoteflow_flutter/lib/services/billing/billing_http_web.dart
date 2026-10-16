// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'billing_http_common.dart';
export 'billing_http_common.dart';

Future<Map<String, dynamic>> billingPost(
  String path,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final request = html.HttpRequest();
  final response = Completer<Map<String, dynamic>>();
  request.open(
    'POST',
    billingEndpoint(path, origin: Uri.base.origin).toString(),
  );
  request.withCredentials = true;
  request.setRequestHeader('Content-Type', 'application/json');
  if (token != null) request.setRequestHeader('Authorization', 'Bearer $token');
  final loaded = request.onLoad.listen((_) {
    try {
      response.complete(
        decodeBillingResponse(
          request.status ?? 0,
          request.responseText ?? '',
          path: path,
        ),
      );
    } catch (error, stack) {
      response.completeError(error, stack);
    }
  });
  final failed = request.onError.listen(
    (_) => response.completeError(
      Exception('The credit server could not be reached.'),
    ),
  );
  try {
    request.send(jsonEncode(body));
    return await response.future.timeout(
      const Duration(seconds: 50),
      onTimeout: () {
        request.abort();
        throw TimeoutException('The credit server did not respond.');
      },
    );
  } finally {
    await loaded.cancel();
    await failed.cancel();
  }
}
