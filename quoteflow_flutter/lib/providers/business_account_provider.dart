import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/billing/billing_http.dart';
import '../services/onboarding/session_store.dart';
import 'billing_provider.dart';

class BusinessAccountProvider extends ChangeNotifier {
  final BillingPost _send;
  final AccountSessionStore _store;
  BusinessAccountProvider({BillingPost? post, AccountSessionStore? store})
    : _send = post ?? billingPost,
      _store = store ?? SecureAccountSessionStore();
  BillingProvider? billing;
  Map<String, dynamic>? account;
  List<Map<String, dynamic>> applications = [];
  String? error;
  String? notice;
  String? mode;
  bool busy = false;
  bool restoring = false;
  bool _disposed = false;
  int _version = 0;
  String? _access;
  String? _refresh;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _refreshing;
  Future<void> _storageWrites = Future.value();
  Future<void> _persist(String? value, int version) {
    final task = _storageWrites.then((_) async {
      if (_disposed || version != _version) return;
      if (value == null) {
        await _store.clear();
      } else {
        await _store.write(value);
      }
    });
    _storageWrites = task.catchError((Object _) {});
    return task;
  }

  final Set<String> _accountWallets = {};
  bool get signedIn => account != null;
  bool get emailVerified => account?['verified'] == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }

  Future<void> restore() async {
    if (restoring || signedIn || _disposed) return;
    final version = _version;
    restoring = true;
    _notify();
    try {
      await _storageWrites;
      final stored = await _store.read();
      if (version != _version || signedIn || _disposed) return;
      _refresh = stored;
      if (_refresh != null || kIsWeb) {
        await _refreshTokens();
        await refreshStatus();
      }
    } on BillingClientException catch (e) {
      if (e.status == 401 && version == _version) {
        await _clearSession();
      }
    } catch (_) {
      /* Offline use must not depend on account restoration. */
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<void> _adopt(Map<String, dynamic> data, int version) async {
    if (_disposed || version != _version) return;
    if (data['accessToken'] is! String || data['account'] is! Map)
      throw const BillingClientException(
        502,
        'The sign-in response could not be verified.',
      );
    final nextAccount = Map<String, dynamic>.from(data['account'] as Map);
    if (!RegExp(
          r'^qfa_[a-f0-9]{64}$',
        ).hasMatch(data['accessToken'] as String) ||
        nextAccount['id'] is! String ||
        nextAccount['email'] is! String ||
        nextAccount['verified'] is! bool ||
        (data['refreshToken'] != null &&
            (data['refreshToken'] is! String ||
                !RegExp(
                  r'^qfr_[a-f0-9]{64}$',
                ).hasMatch(data['refreshToken'] as String)))) {
      throw const BillingClientException(
        502,
        'The sign-in response could not be verified.',
      );
    }
    if (account != null && account!['id'] != nextAccount['id']) {
      for (final tin in _accountWallets) {
        billing?.disconnect(tin);
      }
      _accountWallets.clear();
    }
    _access = data['accessToken'] as String;
    _refresh = data['refreshToken'] as String? ?? _refresh;
    _expires = DateTime.now().add(
      Duration(seconds: (data['expiresIn'] as int? ?? 1800) - 30),
    );
    account = Map<String, dynamic>.from(data['account'] as Map);
    if (_refresh != null) {
      try {
        await _persist(_refresh!, version);
      } catch (_) {
        notice =
            'Signed in for this session. Secure storage is unavailable; sign in again after restarting.';
      }
      if (_disposed || version != _version) {
        return;
      }
    }
  }

  Future<void> _refreshTokens() {
    return _refreshing ??= (() async {
      final version = _version;
      try {
        final data = await _send('/api/onboarding', {
          'action': 'refresh',
          if (!kIsWeb) 'refreshToken': _refresh,
        });
        await _adopt(data, version);
      } on BillingClientException catch (e) {
        if (e.status == 401 && version == _version) await _clearSession();
        rethrow;
      } finally {
        _refreshing = null;
      }
    })();
  }

  Future<String> _token() async {
    if (_access == null || DateTime.now().isAfter(_expires))
      await _refreshTokens();
    if (_access == null)
      throw const BillingClientException(
        401,
        'Sign in to your business account.',
      );
    return _access!;
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> body) async {
    final version = _version;
    var token = await _token();
    try {
      return await _send('/api/onboarding', body, token: token);
    } on BillingClientException catch (e) {
      if (e.status != 401 || version != _version) rethrow;
      await _refreshTokens();
      token = await _token();
      return _send('/api/onboarding', body, token: token);
    }
  }

  Future<Map<String, dynamic>> billingPostWithAccount(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    if (token?.startsWith('qfa_') == true) {
      if (!signedIn)
        throw const BillingClientException(
          401,
          'Sign in to your business account.',
        );
      token = await _token();
    }
    return _send(path, body, token: token);
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notice = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      error = e is BillingClientException
          ? e.message
          : 'Could not reach the business service. Your local documents are still available.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> signIn(
    String email,
    String password, {
    bool register = false,
  }) => _run(() async {
    final version = ++_version;
    final data = await _send('/api/onboarding', {
      'action': register ? 'register' : 'login',
      'email': email.trim(),
      'password': password,
    });
    await _adopt(data, version);
    if (version != _version || _disposed) return;
    if (register)
      notice = data['emailSent'] == true
          ? 'A verification code has been sent to your email.'
          : 'Your account is created. Use Resend code if the email has not arrived.';
    await refreshStatus();
  });
  Future<void> refreshStatus() async {
    if (!signedIn || _disposed) return;
    final version = _version;
    final data = await _request({'action': 'status'});
    if (version != _version || _disposed) return;
    if (data['account'] is! Map || data['applications'] is! List)
      throw const BillingClientException(
        502,
        'Your business application status could not be verified.',
      );
    account = Map<String, dynamic>.from(data['account'] as Map);
    mode = data['mode'] as String?;
    applications = (data['applications'] as List)
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    if (billing != null) {
      for (final app in applications.where((a) => a['state'] == 'approved')) {
        if (version != _version || _disposed) return;
        final tin = app['tin'] as String;
        if (_accountWallets.contains(tin) && billing!.wallet(tin) != null)
          continue;
        if (await billing!.connect(tin, await _token()))
          _accountWallets.add(tin);
      }
    }
    _notify();
  }

  Future<bool> checkStatus() => _run(refreshStatus);
  Future<bool> verify(String code) => _run(() async {
    await _request({'action': 'verify-email', 'code': code.trim()});
    await refreshStatus();
    notice = 'Email verified. Submit your business for review.';
  });
  Future<bool> resend() => _run(() async {
    await _request({'action': 'resend-code'});
    notice = 'A new verification code has been sent.';
  });
  Future<bool> submit(Map<String, dynamic> data) => _run(() async {
    await _request({'action': 'submit', ...data});
    await refreshStatus();
    notice =
        'Application submitted. The QuoteFlow team will review business and device ownership.';
  });
  Future<bool> linkExisting(String tin, String code) => _run(() async {
    await _request({
      'action': 'link-existing',
      'tin': tin.trim(),
      'accessCode': code.trim(),
    });
    await refreshStatus();
    notice = 'Your existing business is linked to your account.';
  });
  Future<bool> upload(String id, String name, String content) => _run(() async {
    await _request({
      'action': 'upload',
      'id': id,
      'name': name,
      'content': content,
    });
    await refreshStatus();
    notice = 'Ownership evidence uploaded securely.';
  });
  Future<bool> requestReset(String email) => _run(() async {
    await _send('/api/onboarding', {
      'action': 'request-reset',
      'email': email.trim(),
    });
    notice = 'If an account exists, a password reset code will be emailed.';
  });
  Future<bool> resetPassword(String email, String code, String password) =>
      _run(() async {
        await _send('/api/onboarding', {
          'action': 'reset-password',
          'email': email.trim(),
          'code': code.trim(),
          'password': password,
        });
        notice = 'Password reset. Sign in with your new password.';
      });
  Future<bool> connectWallet(String tin) => _run(() async {
    await refreshStatus();
    if (!applications.any((a) => a['tin'] == tin && a['state'] == 'approved'))
      throw const BillingClientException(
        403,
        'This account does not have approved access to this business.',
      );
    if (billing == null) throw StateError('Billing is unavailable.');
    if (!await billing!.connect(tin, await _token()))
      throw BillingClientException(
        503,
        billing!.error(tin) ?? 'Could not connect the business wallet.',
      );
    _accountWallets.add(tin);
    notice = 'Your approved business wallet is connected.';
  });
  Future<void> _clearSession() async {
    _version++;
    _access = null;
    _refresh = null;
    account = null;
    applications = [];
    mode = null;
    for (final tin in _accountWallets) {
      billing?.disconnect(tin);
    }
    _accountWallets.clear();
    try {
      await _persist(null, _version);
    } catch (_) {
      /* In-memory logout remains effective. */
    }
    _notify();
  }

  Future<void> signOut() async {
    final token = _access, refresh = _refresh;
    await _clearSession();
    try {
      await _send('/api/onboarding', {
        'action': 'logout',
        if (!kIsWeb) 'refreshToken': refresh,
      }, token: token);
    } catch (_) {
      notice =
          'Signed out on this device. The service could not confirm remote sign-out; use password reset to revoke all sessions if needed.';
      _notify();
    }
  }
}
