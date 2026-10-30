import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';

class DriverArrivingScreen extends StatefulWidget {
  const DriverArrivingScreen({super.key});
  @override
  State<DriverArrivingScreen> createState() => _DriverArrivingScreenState();
}

class _DriverArrivingScreenState extends State<DriverArrivingScreen> {
  int _secs = 240;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // Demo clock runs 12x faster than real time.
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _secs = (_secs - 3).clamp(0, 240).toInt());
      if (_secs == 0) {
        _t?.cancel();
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Cancel this ride?', style: TS.h3),
        content: Text(
            'Mohamed is already on the way. Cancelling now is free, but frequent cancellations may affect your account.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Keep ride', style: TS.label.copyWith(color: TR.navy))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Cancel ride',
                  style: TS.label.copyWith(color: TR.danger))),
        ],
      ),
    );
    if (ok == true && mounted) {
      AppScope.read(context).cancelTrip();
      Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const d = Mock.driver;
    final arrived = _secs == 0;
    final mins = (_secs / 60).ceil();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: TRMap(mode: MapMode.route)),
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TRBack(light: true),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(arrived),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                arrived
                                    ? 'Your driver is here'
                                    : 'Arriving in $mins min',
                                style: TS.h2.copyWith(fontSize: 22)),
                            Text(
                                arrived
                                    ? 'Look for ${d.plate} at the gate'
                                    : 'Meet at the gate on Wilkinson Road',
                                style: TS.small),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: TR.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        Text('RIDE PIN',
                            style: TS.caps.copyWith(
                                color: const Color(0xFFB9CBE2), fontSize: 10)),
                        Text('4827',
                            style: TS.h3.copyWith(
                                color: Colors.white, letterSpacing: 3)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1 - _secs / 240,
                      minHeight: 6,
                      backgroundColor: TR.line,
                      color: TR.green,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: TR.surface,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Avatar(d.initials, size: 56, ring: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name, style: TS.label.copyWith(fontSize: 16)),
                            Row(children: [
                              const Icon(PhosphorIconsFill.star,
                                  color: TR.gold, size: 14),
                              Text(' ${d.rating} · ${d.trips} trips',
                                  style: TS.small),
                            ]),
                            const Pill('Verified driver',
                                icon: PhosphorIconsFill.sealCheck),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: TR.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(d.plate,
                                style: TS.label.copyWith(letterSpacing: 1)),
                          ),
                          const SizedBox(height: 4),
                          Text(d.car, style: TS.small.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _action(PhosphorIconsFill.phone, 'Call',
                        () => showToast(context, 'Calling Mohamed…',
                            icon: PhosphorIconsFill.phoneCall)),
                    const SizedBox(width: 10),
                    _action(PhosphorIconsFill.chatCircleDots, 'Message',
                        () => showToast(context, 'Chat opened',
                            icon: PhosphorIconsFill.chatCircleDots)),
                    const SizedBox(width: 10),
                    _action(PhosphorIconsFill.shareNetwork, 'Share trip',
                        () => showToast(context,
                            'Live trip shared with your trusted contacts')),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: TR.greenTint,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.shieldCheck,
                          color: TR.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'Check the plate and ask your driver for the PIN before you get in.',
                            style: TS.small.copyWith(color: TR.ink)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: TRButton(
                          label: 'Cancel',
                          kind: BtnKind.outline,
                          height: 54,
                          onPressed: _cancel),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TRButton(
                        label: "I'm in the car",
                        height: 54,
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed(R.onTrip),
                      ),
                    ),
                  ]),
                ],
              ),
            ).animate().slideY(
                begin: 0.4, duration: 500.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TR.line),
            ),
            child: Column(children: [
              Icon(icon, color: TR.navy, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TS.label.copyWith(fontSize: 13)),
            ]),
          ),
        ),
      );
}
