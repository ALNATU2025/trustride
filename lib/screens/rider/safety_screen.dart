import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/location_service.dart';
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

  Future<void> _trigger() async {
    HapticFeedback.heavyImpact();
    _hold.reset();
    final s = AppScope.read(context);
    final p = s.profile;
    if (p == null) return;
    try {
      final at = await LocationService.current();
      await Db.raiseSos(user: p, tripId: s.currentTripId ?? '', at: at);
      if (!mounted) return;
      showToast(context, 'SOS sent to the TrustRide safety team',
          icon: PhosphorIconsFill.siren);
      await launchUrl(Uri(scheme: 'tel', path: s.config.policeNumber));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _addContact(String uid) async {
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
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Name')),
          const SizedBox(height: 10),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone, e.g. 77 000 000')),
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
    final n = name.text.trim(), ph = phone.text.trim();
    name.dispose();
    phone.dispose();
    if (ok != true || n.isEmpty || ph.isEmpty) return;
    try {
      await Db.addContact(uid, Contact(n, AuthService.normalise(ph)));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    if (p == null) return const Scaffold(body: Loading());
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
                        Text('SOS', style: TS.h3.copyWith(color: Colors.white)),
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
                                  : 'Press and hold for 3 seconds. We alert our safety team with your location, then call ${s.config.policeNumber}.',
                              style: TS.small.copyWith(color: const Color(0xFFFFE1E1))),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: 12),
            Row(children: [
              _call(PhosphorIconsFill.shieldStar, 'Police', s.config.policeNumber),
              const SizedBox(width: 10),
              _call(PhosphorIconsFill.firstAid, 'Ambulance', s.config.ambulanceNumber),
            ]),
            const SizedBox(height: 22),
            const Caps('Trusted contacts'),
            const SizedBox(height: 10),
            if (p.contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Add someone we can alert, and who you can share trips with.',
                    style: TS.small),
              ),
            for (final c in p.contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                    color: TR.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Avatar(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: TS.label.copyWith(fontSize: 14)),
                        Text(c.phone, style: TS.small.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => Db.removeContact(p.uid, c),
                    icon: const Icon(PhosphorIconsBold.x, size: 18, color: TR.muted),
                  ),
                ]),
              ),
            Pressable(
              onTap: () => _addContact(p.uid),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB7C3D1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsBold.userPlus, size: 18, color: TR.navy),
                    const SizedBox(width: 8),
                    Text('Add trusted contact', style: TS.label.copyWith(color: TR.navy)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Caps('Ride settings'),
            const SizedBox(height: 10),
            _toggle(p.uid, 'requirePin', 'Require ride PIN',
                'Driver must enter your PIN to start', p.requirePin),
            _toggle(p.uid, 'shareNight', 'Remind me to share night trips',
                'After 9 PM we prompt you to share your trip', p.shareNight),
          ],
        ),
      ),
    );
  }

  Widget _call(IconData icon, String label, String number) => Expanded(
        child: Pressable(
          onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
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

  Widget _toggle(String uid, String key, String title, String sub, bool v) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: TR.surface, borderRadius: BorderRadius.circular(16)),
        child: SwitchListTile(
          value: v,
          onChanged: (nv) => Db.setSetting(uid, key, nv),
          activeTrackColor: TR.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: TS.label),
          subtitle: Text(sub, style: TS.small.copyWith(fontSize: 12)),
        ),
      );
}
