import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_logo.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Overlays a full-screen lock whenever QuoteFlow is protected and either
/// the app was just opened or it is returning from the background.
///
/// This is designed to be installed via [MaterialApp.builder], so the lock
/// covers every route (including pushed screens) while the Navigator below
/// stays alive — unlocking never resets the navigation stack.
class LockGate extends StatefulWidget {
  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = context.read<AppSettingsProvider>().appLockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled = context.read<AppSettingsProvider>().appLockEnabled;
    if (!enabled) return;
    // Lock as soon as the app leaves the foreground (Android backgrounding,
    // iOS app switcher) so the next time it is opened a PIN is required.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (mounted && !_locked) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final enabled = settings.appLockEnabled;
    if (!enabled) _locked = false;

    // Always keep the Navigator at index 0 of a Stack so its element (and
    // therefore the route stack) survives locking and unlocking.
    return Stack(
      children: [
        widget.child,
        if (enabled && _locked)
          Positioned.fill(
            // The lock screen sits above the Navigator (whose Overlay lives
            // inside it), so it needs its own Overlay for the PIN field's
            // text editing to work.
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => _LockScreen(
                    pin: settings.appLockPin,
                    biometrics: settings.appLockBiometrics,
                    onUnlocked: () => setState(() => _locked = false),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The full-screen PIN / biometric prompt shown on top of the app.
class _LockScreen extends StatefulWidget {
  final String? pin;
  final bool biometrics;
  final VoidCallback onUnlocked;

  const _LockScreen({
    required this.pin,
    required this.biometrics,
    required this.onUnlocked,
  });

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    final pin = widget.pin;
    if (pin == null || pin.isEmpty) {
      setState(() => _error = 'No PIN is set. Disable App Lock in Settings.');
      return;
    }
    if (_pinCtrl.text == pin) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _error = 'Incorrect PIN. Please try again.';
      _pinCtrl.clear();
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = LocalAuthentication();
    var ok = false;
    try {
      ok = await auth.authenticate(
        localizedReason: 'Unlock QuoteFlow',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(
        () => _error = 'Biometric unlock failed. Enter your PIN instead.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 24),
                  Text(
                    'QuoteFlow is locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your PIN to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _pinCtrl,
                      autofocus: true,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 26,
                        letterSpacing: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: TextStyle(
                          fontSize: 26,
                          letterSpacing: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 240,
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: const Text('Unlock'),
                    ),
                  ),
                  if (widget.biometrics && !kIsWeb) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 20),
                      label: Text(
                        _busy ? 'Checking…' : 'Unlock with fingerprint',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
