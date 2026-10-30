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

class OnTripScreen extends StatefulWidget {
  const OnTripScreen({super.key});
  @override
  State<OnTripScreen> createState() => _OnTripScreenState();
}

class _OnTripScreenState extends State<OnTripScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _trip = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        if (mounted) setState(() {});
      }
    })
    ..forward();

  @override
  void dispose() {
    _trip.dispose();
    super.dispose();
  }

  void _sos() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => BottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            Row(children: [
              const IconBubble(PhosphorIconsFill.siren,
                  color: TR.danger, bg: TR.dangerTint, size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text('Emergency assistance', style: TS.h3)),
            ]),
            const SizedBox(height: 10),
            Text(
                'Your live location, driver and plate will be shared with the TrustRide safety team and your trusted contacts.',
                style: TS.body),
            const SizedBox(height: 16),
            TRButton(
              label: 'Call police · 999',
              kind: BtnKind.danger,
              icon: PhosphorIconsFill.phoneCall,
              onPressed: () {
                Navigator.pop(c);
                showToast(context, 'Calling 999 and alerting TrustRide safety',
                    icon: PhosphorIconsFill.siren);
              },
            ),
            const SizedBox(height: 10),
            TRButton(
              label: 'Alert my trusted contacts',
              kind: BtnKind.outline,
              onPressed: () {
                Navigator.pop(c);
                showToast(context, 'Trusted contacts alerted with your location');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    const d = Mock.driver;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _trip,
        builder: (context, _) {
          final p = _trip.value;
          final done = _trip.isCompleted;
          final kmLeft = (s.destination.km * (1 - p));
          final minLeft = (s.tripMinutes * (1 - p)).ceil();
          final eta = TimeOfDay.fromDateTime(
              DateTime.now().add(Duration(minutes: minLeft)));
          return Stack(
            children: [
              Positioned.fill(
                  child: TRMap(mode: MapMode.tracking, progress: p)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: TR.brandGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: TR.shadow(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ARRIVE BY',
                                style: TS.caps.copyWith(
                                    color: const Color(0xFFB9CBE2),
                                    fontSize: 10)),
                            Text(eta.format(context),
                                style: TS.h3.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: _sos,
                        semanticLabel: 'SOS emergency',
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: TR.danger,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                  color: TR.danger.fade(0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Row(children: [
                            const Icon(PhosphorIconsFill.siren,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text('SOS',
                                style: TS.label.copyWith(
                                    color: Colors.white, fontSize: 16)),
                          ]),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(end: 1.05, duration: 900.ms),
                    ],
                  ),
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
                          child: Text(
                              done
                                  ? 'You’ve arrived'
                                  : 'Heading to ${s.destination.name}',
                              style: TS.h3.copyWith(fontSize: 20)),
                        ),
                        Text(done ? 'Done' : '$minLeft min',
                            style: TS.label.copyWith(color: TR.green)),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: p,
                          minHeight: 8,
                          backgroundColor: TR.line,
                          color: TR.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          done
                              ? '${s.destination.name} · ${s.destination.area}'
                              : '${kmLeft.toStringAsFixed(1)} km left · via Wilkinson Road',
                          style: TS.small),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: TR.surface,
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          Avatar(d.initials, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mohamed · ${d.plate}', style: TS.label),
                                Text(d.car, style: TS.small.copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(TR.le(s.fare), style: TS.h3),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      if (!done)
                        Row(children: [
                          Expanded(
                            child: TRButton(
                              label: 'Share trip',
                              kind: BtnKind.outline,
                              height: 50,
                              onPressed: () => showToast(context,
                                  'Live trip link sent to your trusted contacts'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TRButton(
                              label: 'Skip ahead',
                              kind: BtnKind.outline,
                              height: 50,
                              onPressed: () => _trip.animateTo(1,
                                  duration: const Duration(milliseconds: 900)),
                            ),
                          ),
                        ])
                      else
                        TRButton(
                          label: 'See fare & pay',
                          icon: PhosphorIconsBold.arrowRight,
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed(R.payment),
                        ).animate().fadeIn().scale(
                            begin: const Offset(0.9, 0.9),
                            curve: Curves.easeOutBack),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
