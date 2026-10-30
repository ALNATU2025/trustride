import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});
  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _trigger();
    });

  void _trigger() {
    HapticFeedback.heavyImpact();
    _hold.reset();
    showToast(context,
        'SOS sent: TrustRide safety team and your trusted contacts have your live location',
        icon: PhosphorIconsFill.siren);
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _addContact(AppState s) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add trusted contact', style: TS.h3),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(hintText: 'Name')),
          const SizedBox(height: 10),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+232 …')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Save', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      s.addContact('${name.text.trim()} · ${phone.text.trim()}');
    }
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(children: [
              const TRBack(),
              const SizedBox(width: 12),
              Text('Safety centre', style: TS.h3.copyWith(fontSize: 22)),
            ]),
            const SizedBox(height: 18),
            GestureDetector(
              onLongPressStart: (_) {
                HapticFeedback.mediumImpact();
                _hold.forward(from: 0);
              },
              onLongPressEnd: (_) {
                if (!_hold.isCompleted) _hold.reverse();
              },
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TR.danger,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: TR.danger.fade(0.3 + 0.3 * _hold.value),
                          blurRadius: 24 + 20 * _hold.value,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: _hold.value,
                            strokeWidth: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white.fade(0.2),
                          ),
                        ),
                        Text('SOS',
                            style: TS.h3.copyWith(color: Colors.white)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Emergency assistance',
                              style: TS.h3.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                              _hold.value > 0
                                  ? 'Keep holding… ${(3 - 3 * _hold.value).ceil()}s'
                                  : 'Press and hold for 3 seconds to alert police, your contacts and our safety team.',
                              style: TS.small.copyWith(
                                  color: const Color(0xFFFFE1E1))),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: 12),
            Row(children: [
              _call(PhosphorIconsFill.shieldStar, 'Police', '999'),
              const SizedBox(width: 10),
              _call(PhosphorIconsFill.firstAid, 'Ambulance (NEMS)', '117'),
            ]),
            const SizedBox(height: 22),
            const Caps('Trusted contacts'),
            const SizedBox(height: 10),
            for (final c in s.trustedContacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: TR.surface,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Avatar(c.isNotEmpty ? c[0].toUpperCase() : '?', size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c, style: TS.label.copyWith(fontSize: 14))),
                  const Icon(PhosphorIconsFill.checkCircle,
                      color: TR.green, size: 20),
                ]),
              ),
            Pressable(
              onTap: () => _addContact(s),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB7C3D1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsBold.userPlus,
                        size: 18, color: TR.navy),
                    const SizedBox(width: 8),
                    Text('Add trusted contact',
                        style: TS.label.copyWith(color: TR.navy)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Caps('Ride settings'),
            const SizedBox(height: 10),
            _toggle(s, 'pin', 'Require ride PIN',
                'Driver must confirm your PIN to start', s.requirePin),
            _toggle(s, 'night', 'Auto-share night trips',
                'After 9 PM, contacts get your live trip', s.shareNightTrips),
            _toggle(s, 'female', 'Female drivers preferred',
                'When available nearby', s.preferFemaleDrivers),
          ],
        ),
      ),
    );
  }

  Widget _call(IconData icon, String label, String number) => Expanded(
        child: Pressable(
          onTap: () => showToast(context, 'Calling $label · $number',
              icon: PhosphorIconsFill.phoneCall),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TR.line),
            ),
            child: Row(children: [
              Icon(icon, color: TR.navy, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TS.small.copyWith(fontSize: 12)),
                    Text('Call $number', style: TS.h3),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _toggle(AppState s, String key, String title, String sub, bool v) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: TR.surface, borderRadius: BorderRadius.circular(16)),
        child: SwitchListTile(
          value: v,
          onChanged: (_) => s.toggleSetting(key),
          activeTrackColor: TR.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: TS.label),
          subtitle: Text(sub, style: TS.small.copyWith(fontSize: 12)),
        ),
      );
}
