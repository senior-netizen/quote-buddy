import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AccountSessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Native refresh tokens live in OS-protected storage. Browser refresh tokens
/// are managed exclusively by the server's Secure, HttpOnly cookie.
class SecureAccountSessionStore implements AccountSessionStore {
  static const _key = 'quoteflow_business_refresh_v1';
  final FlutterSecureStorage storage;
  SecureAccountSessionStore({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  @override
  Future<String?> read() async => kIsWeb ? null : storage.read(key: _key);
  @override
  Future<void> write(String value) async {
    if (!kIsWeb) await storage.write(key: _key, value: value);
  }

  @override
  Future<void> clear() async {
    if (!kIsWeb) await storage.delete(key: _key);
  }
}
