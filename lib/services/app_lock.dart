import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional app lock: a 4-digit PIN, with fingerprint / face unlock on
/// phones that support it. Stored encrypted on the device only.
/// Not available on the web (the admin console).
class AppLock extends ChangeNotifier {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const _storage = FlutterSecureStorage();
  static const _kPin = 'tr_lock_pin';
  static const _kBio = 'tr_lock_bio';

  final _auth = LocalAuthentication();

  bool loaded = false;
  bool enabled = false;
  bool biometrics = false;
  bool biometricsAvailable = false;

  /// True while the lock screen should cover the app.
  bool locked = false;
  DateTime? _pausedAt;

  bool get supported => !kIsWeb;

  Future<void> load() async {
    if (!supported) {
      loaded = true;
      return;
    }
    try {
      final pin = await _storage.read(key: _kPin);
      enabled = pin != null && pin.length == 4;
      biometrics = enabled && (await _storage.read(key: _kBio)) == '1';
      biometricsAvailable =
          await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      enabled = false;
    }
    locked = enabled;
    loaded = true;
    notifyListeners();
  }

  Future<bool> checkPin(String pin) async {
    final saved = await _storage.read(key: _kPin);
    final ok = saved != null && saved == pin;
    if (ok) unlock();
    return ok;
  }

  Future<void> setPin(String pin, {required bool useBiometrics}) async {
    await _storage.write(key: _kPin, value: pin);
    await _storage.write(key: _kBio, value: useBiometrics ? '1' : '0');
    enabled = true;
    biometrics = useBiometrics;
    notifyListeners();
  }

  Future<void> setBiometrics(bool on) async {
    await _storage.write(key: _kBio, value: on ? '1' : '0');
    biometrics = on;
    notifyListeners();
  }

  Future<void> disable() async {
    await _storage.delete(key: _kPin);
    await _storage.delete(key: _kBio);
    enabled = false;
    biometrics = false;
    locked = false;
    notifyListeners();
  }

  /// Shows the fingerprint / face prompt. Returns true when it succeeded.
  Future<bool> tryBiometrics() async {
    if (!biometrics || !biometricsAvailable) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock TrustRide',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) unlock();
      return ok;
    } catch (_) {
      return false;
    }
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  /// Lock again when the app was in the background for over 30 seconds.
  void onPaused() => _pausedAt = DateTime.now();

  void onResumed() {
    final at = _pausedAt;
    _pausedAt = null;
    if (enabled && at != null &&
        DateTime.now().difference(at) > const Duration(seconds: 30)) {
      locked = true;
      notifyListeners();
    }
  }
}
