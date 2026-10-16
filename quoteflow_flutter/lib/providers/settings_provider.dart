import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const _darkModeKey = 'darkMode';
  static const _appLockEnabledKey = 'appLockEnabled';
  static const _appLockPinKey = 'appLockPin';
  static const _appLockBiometricsKey = 'appLockBiometrics';

  bool _darkMode = false;
  bool _appLockEnabled = false;
  String? _appLockPin;
  bool _appLockBiometrics = false;

  bool get darkMode => _darkMode;
  bool get appLockEnabled => _appLockEnabled;
  String? get appLockPin => _appLockPin;
  bool get appLockBiometrics => _appLockBiometrics;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_darkModeKey) ?? false;
    _appLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    _appLockPin = prefs.getString(_appLockPinKey);
    _appLockBiometrics = prefs.getBool(_appLockBiometricsKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _darkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _darkMode);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, _appLockEnabled);
    notifyListeners();
  }

  Future<void> setAppLockPin(String? pin) async {
    _appLockPin = pin;
    final prefs = await SharedPreferences.getInstance();
    if (pin != null) {
      await prefs.setString(_appLockPinKey, pin);
    } else {
      await prefs.remove(_appLockPinKey);
    }
    notifyListeners();
  }

  Future<void> setAppLockBiometrics(bool value) async {
    _appLockBiometrics = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockBiometricsKey, value);
    notifyListeners();
  }
}
