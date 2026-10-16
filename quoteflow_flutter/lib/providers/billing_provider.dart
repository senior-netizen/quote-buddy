import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/billing/billing_http.dart';
import '../services/zimra/zimra.dart';

typedef BillingPost =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> body, {
      String? token,
    });

class _BusinessSession {
  final String token;
  Map<String, dynamic> wallet;
  String? requestId;
  _BusinessSession(this.token, this.wallet);
}

class BillingProvider extends ChangeNotifier {
  final BillingPost _post;
  BillingProvider({BillingPost? post}) : _post = post ?? billingPost;
  final Map<String, _BusinessSession> _sessions = {};
  final Map<String, String> _errors = {};
  final Set<String> _busy = {};
  final Set<String> _refreshPending = {};
  bool _disposed = false;
  final Map<String, int> _sessionVersions = {};

  void _finish(String tin) {
    _busy.remove(tin);
    if (_disposed) return;
    notifyListeners();
    if (_refreshPending.remove(tin)) unawaited(refresh(tin));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Map<String, dynamic>? wallet(String tin) => _sessions[tin]?.wallet;
  String? error(String tin) => _errors[tin];
  bool isBusy(String tin) => _busy.contains(tin);

  Future<bool> connect(String tin, String token) async {
    if (_disposed || _busy.contains(tin)) return false;
    final version = _sessionVersions[tin] ?? 0;
    _busy.add(tin);
    _errors.remove(tin);
    notifyListeners();
    try {
      final data = await _post('/api/billing/balance', {
        'businessTin': tin,
      }, token: token.trim());
      _validateWallet(tin, data);
      if (_disposed || (_sessionVersions[tin] ?? 0) != version) return false;
      _sessions[tin] = _BusinessSession(token.trim(), data);
      return true;
    } catch (error) {
      if (!_disposed && (_sessionVersions[tin] ?? 0) == version) {
        _errors[tin] = _message(error);
      }
      return false;
    } finally {
      _finish(tin);
    }
  }

  void _validateWallet(String tin, Map<String, dynamic> data) {
    if (data['businessTin'] != tin ||
        !const {'test', 'live'}.contains(data['mode']) ||
        data['available'] is! int ||
        data['deviceIds'] is! List) {
      throw const BillingClientException(
        502,
        'The credit balance could not be verified.',
      );
    }
  }

  Future<void> refresh(String tin) async {
    final session = _sessions[tin];
    if (session == null || _disposed) return;
    if (_busy.contains(tin)) {
      _refreshPending.add(tin);
      return;
    }
    _busy.add(tin);
    _errors.remove(tin);
    notifyListeners();
    try {
      final data = await _post('/api/billing/balance', {
        'businessTin': tin,
      }, token: session.token);
      _validateWallet(tin, data);
      session.wallet = data;
    } catch (error) {
      _errors[tin] = _message(error);
    } finally {
      _finish(tin);
    }
  }

  Future<Map<String, dynamic>?> buyCredits(
    String tin, {
    String method = 'bank',
    String phone = '',
    String email = '',
  }) async {
    final session = _sessions[tin];
    if (session == null || _busy.contains(tin)) return null;
    _busy.add(tin);
    _errors.remove(tin);
    notifyListeners();
    session.requestId ??= const Uuid().v4();
    try {
      final order = await _post('/api/billing/topups', {
        'businessTin': tin,
        'requestId': session.requestId,
        'method': method,
        'phone': phone,
        'email': email,
      }, token: session.token);
      if (order['reference'] is! String || order['status'] is! String) {
        throw const BillingClientException(
          502,
          'The payment request could not be verified. Refresh before trying again.',
        );
      }
      final payments = (session.wallet['payments'] as List? ?? [])
          .whereType<Map>()
          .where((p) => p['reference'] != order['reference'])
          .toList();
      session.wallet = {
        ...session.wallet,
        'payments': [order, ...payments],
      };
      session.requestId = null;
      return order;
    } catch (error) {
      _errors[tin] = _message(error);
      return null;
    } finally {
      _finish(tin);
    }
  }

  void disconnect(String tin) {
    _sessionVersions[tin] = (_sessionVersions[tin] ?? 0) + 1;
    _sessions.remove(tin);
    _errors.remove(tin);
    _refreshPending.remove(tin);
    notifyListeners();
  }

  Future<void> verifyPayment(String tin, String reference) async {
    final session = _sessions[tin];
    if (session == null || _busy.contains(tin)) return;
    _busy.add(tin);
    _errors.remove(tin);
    notifyListeners();
    try {
      await _post('/api/billing/payment', {
        'businessTin': tin,
        'reference': reference,
        'completed': true,
      }, token: session.token);
      final data = await _post('/api/billing/balance', {
        'businessTin': tin,
      }, token: session.token);
      _validateWallet(tin, data);
      session.wallet = data;
    } catch (error) {
      _errors[tin] = _message(error);
    } finally {
      _finish(tin);
    }
  }

  String _message(Object error) => error is BillingClientException
      ? error.message
      : 'The credit server could not be reached. Your payment or balance may still be pending; reconnect and refresh before trying again.';

  Future<Map<String, dynamic>?> simulateDeduction(
    String tin,
    String runId,
    String receiptId,
  ) async {
    final session = _sessions[tin];
    if (session == null ||
        session.wallet['mode'] != 'test' ||
        _busy.contains(tin)) {
      return null;
    }
    _busy.add(tin);
    _errors.remove(tin);
    notifyListeners();
    try {
      final data = await _post('/api/billing/simulate', {
        'businessTin': tin,
        'runId': runId,
        'receiptId': receiptId,
      }, token: session.token);
      if (data['mode'] != 'simulation' ||
          data['available'] is! int ||
          data['used'] is! int) {
        throw const BillingClientException(
          502,
          'The demo balance could not be verified.',
        );
      }
      return data;
    } catch (error) {
      _errors[tin] = _message(error);
      return null;
    } finally {
      _finish(tin);
    }
  }

  ZimraApi? testTransport(
    ZimraDeviceIdentity identity,
    ZimraCredentials credentials,
  ) {
    final transport = _walletTransport(
      identity,
      credentials,
      ZimraEnvironment.test,
    );
    if (transport != null) return transport;
    if (_sessions.values.any((session) => session.wallet['mode'] == 'test')) {
      throw const ZimraException(
        'BILLING_AUTH',
        'This test device is not assigned to a connected test wallet. Connect the matching business wallet before fiscalising.',
      );
    }
    return null;
  }

  ZimraApi productionTransport(
    ZimraDeviceIdentity identity,
    ZimraCredentials credentials,
  ) {
    final transport = _walletTransport(
      identity,
      credentials,
      ZimraEnvironment.production,
    );
    if (transport != null) return transport;
    throw const ZimraException(
      'BILLING_AUTH',
      'Connect this business to a live credit wallet before using production. A test wallet cannot fund production fiscalisation.',
    );
  }

  ZimraApi? _walletTransport(
    ZimraDeviceIdentity identity,
    ZimraCredentials credentials,
    ZimraEnvironment environment,
  ) {
    final mode = environment == ZimraEnvironment.test ? 'test' : 'live';
    for (final entry in _sessions.entries) {
      if (entry.value.wallet['mode'] == mode &&
          (entry.value.wallet['deviceIds'] as List).contains(
            identity.deviceId,
          )) {
        return _BilledTransport(
          identity,
          credentials,
          entry.key,
          entry.value.token,
          _post,
          () => refresh(entry.key),
          () => !_disposed && identical(_sessions[entry.key], entry.value),
          environment,
        );
      }
    }
    return null;
  }
}

class _BilledTransport implements ZimraApi {
  final ZimraDeviceIdentity identity;
  final ZimraCredentials credentials;
  final ZimraEnvironment environment;
  final String tin;
  final String token;
  final BillingPost send;
  final Future<void> Function() refresh;
  final bool Function() isConnected;
  _BilledTransport(
    this.identity,
    this.credentials,
    this.tin,
    this.token,
    this.send,
    this.refresh,
    this.isConnected,
    this.environment,
  );

  Future<ZimraHttpResponse> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    try {
      if (!isConnected()) {
        throw const BillingClientException(
          401,
          'Business disconnected. Reconnect before using production fiscalisation.',
        );
      }
      final result = await send(
        environment == ZimraEnvironment.test ? '/api/zimra/test' : '/api/zimra',
        {
          'businessTin': tin,
          'baseUrl': environment.baseUrl,
          'method': method,
          'path': path,
          'headers': identity.requestHeaders,
          'certificatePem': credentials.certificatePem,
          'privateKeyPem': credentials.privateKeyPem,
          'body': ?body,
        },
        token: token,
      );
      if (result['uncertain'] == true) {
        throw Exception(
          'Fiscal submission is pending; the same signed receipt must be retried.',
        );
      }
      final raw = result['rawBody'] as String? ?? '';
      Map<String, dynamic> parsed = {};
      try {
        parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
      return ZimraHttpResponse(
        statusCode: result['statusCode'] as int,
        body: parsed,
        rawBody: raw,
      );
    } on BillingClientException catch (error) {
      if (error.status >= 500) rethrow;
      final problem = {'title': error.message};
      return ZimraHttpResponse(
        statusCode: error.status,
        body: problem,
        rawBody: jsonEncode(problem),
      );
    } finally {
      // Unknown outcomes reserve a credit too; refresh after every submission.
      if (path.endsWith('/SubmitReceipt')) unawaited(refresh());
    }
  }

  @override
  Future<ZimraHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => _request('POST', path, body);
  @override
  Future<ZimraHttpResponse> get(String path, {Map<String, String>? headers}) =>
      _request('GET', path, null);
  @override
  void close() {}
}
