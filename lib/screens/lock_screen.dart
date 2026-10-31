import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../services/app_lock.dart';
import '../widgets/common.dart';

/// Wraps the whole app: shows [LockScreen] on top while the app is locked
/// and re-locks after 30 seconds in the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final lock = AppLock.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lock.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) lock.onPaused();
    if (state == AppLifecycleState.resumed) lock.onResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    lock.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (lock.locked)
        const Positioned.fill(child: LockScreen())
            .animate()
            .fadeIn(duration: 200.ms),
    ]);
  }
}

/// Reusable 4-digit PIN keypad.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.dark = false,
  });

  final int length;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : TR.ink;
    Widget key(String label, {VoidCallback? onTap, IconData? icon, String? semantics}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Pressable(
              onTap: onTap,
              semanticLabel: semantics ?? label,
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: onTap == null
                      ? Colors.transparent
                      : (dark ? Colors.white.fade(0.08) : TR.field),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, color: fg, size: 26)
                    : Text(label, style: TS.h2.copyWith(color: fg, fontSize: 26)),
              ),
            ),
          ),
        );

    Widget digit(String d) => key(d, onTap: () {
          HapticFeedback.selectionClick();
          onDigit(d);
        });

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final on = i < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: on ? 18 : 16,
            height: on ? 18 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? TR.greenBright : Colors.transparent,
              border: Border.all(color: on ? TR.greenBright : fg.fade(0.4), width: 2),
            ),
          );
        }),
      ),
      const SizedBox(height: 28),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(children: [for (final d in row) digit(d)]),
      Row(children: [
        key('', onTap: onBiometric, icon: onBiometric == null ? null : PhosphorIconsBold.fingerprint,
            semantics: 'Use fingerprint or face'),
        digit('0'),
        key('', onTap: onDelete, icon: PhosphorIconsBold.backspace, semantics: 'Delete'),
      ]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;
  int _attempts = 0;
  final lock = AppLock.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => lock.tryBiometrics());
  }

  Future<void> _digit(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length == 4) {
      final ok = await lock.checkPin(_pin);
      if (!ok && mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _wrong = true;
          _pin = '';
          _attempts++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TR.navy, TR.navyDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMark(size: 72)
                        .animate()
                        .scale(curve: Curves.easeOutBack, duration: 500.ms),
                    const SizedBox(height: 20),
                    Text('Enter your PIN', style: TS.h2.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _wrong
                            ? (_attempts >= 5
                                ? 'Wrong PIN. Forgot it? Reinstall the app or clear its data, then sign in again.'
                                : 'Wrong PIN, try again')
                            : 'TrustRide is locked',
                        key: ValueKey('$_wrong$_attempts'),
                        textAlign: TextAlign.center,
                        style: TS.small.copyWith(
                            color: _wrong ? const Color(0xFFFFB4B4) : const Color(0xFFB9CBE2)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    PinPad(
                      dark: true,
                      length: _pin.length,
                      onDigit: _digit,
                      onDelete: () => setState(() {
                        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                      }),
                      onBiometric: lock.biometrics && lock.biometricsAvailable
                          ? lock.tryBiometrics
                          : null,
                    ).animate(target: _wrong ? 1.0 : 0.0).shake(hz: 5, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
