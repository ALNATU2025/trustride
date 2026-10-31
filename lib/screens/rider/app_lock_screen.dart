import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../services/app_lock.dart';
import '../../widgets/common.dart';
import '../lock_screen.dart';

/// Settings: turn the PIN lock on/off and use fingerprint / face.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final lock = AppLock.instance;
  bool _setting = false;
  String _first = '';
  String _pin = '';
  String? _msg;

  @override
  void initState() {
    super.initState();
    lock.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    lock.removeListener(_changed);
    super.dispose();
  }

  Future<void> _digit(String d) async {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length < 4) return;
    if (_first.isEmpty) {
      setState(() {
        _first = _pin;
        _pin = '';
        _msg = null;
      });
      return;
    }
    if (_pin != _first) {
      setState(() {
        _first = '';
        _pin = '';
        _msg = 'The PINs didn’t match. Start again.';
      });
      return;
    }
    await lock.setPin(_pin, useBiometrics: lock.biometricsAvailable);
    if (!mounted) return;
    setState(() {
      _setting = false;
      _first = '';
      _pin = '';
      _msg = null;
    });
    showToast(context, 'App lock is on', icon: PhosphorIconsFill.lockSimple);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const ScreenTitle('App lock', back: true),
            const SizedBox(height: 18),
            if (!lock.supported)
              const EmptyState(
                icon: PhosphorIconsFill.lockSimple,
                title: 'Available on the phone app',
                body: 'App lock works on Android phones.',
              )
            else if (_setting) ...[
              Text(_first.isEmpty ? 'Choose a 4-digit PIN' : 'Enter the PIN again',
                      textAlign: TextAlign.center, style: TS.h3)
                  .animate(key: ValueKey(_first.isEmpty))
                  .fadeIn(),
              const SizedBox(height: 6),
              Text(_msg ?? 'You’ll use it to open TrustRide.',
                  textAlign: TextAlign.center,
                  style: TS.small.copyWith(color: _msg != null ? TR.danger : TR.muted)),
              const SizedBox(height: 26),
              PinPad(
                length: _pin.length,
                onDigit: _digit,
                onDelete: () => setState(() {
                  if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                }),
              ),
              const SizedBox(height: 12),
              TRButton(
                  label: 'Cancel',
                  kind: BtnKind.ghost,
                  onPressed: () => setState(() {
                        _setting = false;
                        _first = '';
                        _pin = '';
                        _msg = null;
                      })),
            ] else ...[
              Center(
                child: IconBubble(
                  lock.enabled ? PhosphorIconsFill.lockSimple : PhosphorIconsFill.lockSimpleOpen,
                  size: 88,
                  color: lock.enabled ? TR.green : TR.navy,
                  bg: lock.enabled ? TR.greenTint : TR.field,
                ).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
              ),
              const SizedBox(height: 16),
              Text(lock.enabled ? 'App lock is on' : 'Protect your account',
                  textAlign: TextAlign.center, style: TS.h2),
              const SizedBox(height: 6),
              Text(
                  'Ask for a PIN or your fingerprint each time TrustRide opens, and after 30 seconds in the background.',
                  textAlign: TextAlign.center,
                  style: TS.body),
              const SizedBox(height: 22),
              if (lock.enabled) ...[
                if (lock.biometricsAvailable)
                  Container(
                    decoration: BoxDecoration(
                        color: TR.surface, borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile(
                      value: lock.biometrics,
                      onChanged: (v) => lock.setBiometrics(v),
                      activeTrackColor: TR.green,
                      secondary: const Icon(PhosphorIconsFill.fingerprint, color: TR.navy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Fingerprint / face unlock', style: TS.label),
                      subtitle: Text('Use instead of typing your PIN',
                          style: TS.small.copyWith(fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 12),
                TRButton(
                    label: 'Change PIN',
                    kind: BtnKind.outline,
                    onPressed: () => setState(() => _setting = true)),
                const SizedBox(height: 10),
                TRButton(
                    label: 'Turn off app lock',
                    kind: BtnKind.ghost,
                    onPressed: () async {
                      await lock.disable();
                      if (context.mounted) showToast(context, 'App lock is off');
                    }),
              ] else
                TRButton(
                    label: 'Set a PIN',
                    icon: PhosphorIconsBold.arrowRight,
                    onPressed: () => setState(() => _setting = true)),
            ],
          ],
        ),
      ),
    );
  }
}
