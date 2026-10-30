import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class FindingScreen extends StatefulWidget {
  const FindingScreen({super.key});
  @override
  State<FindingScreen> createState() => _FindingScreenState();
}

class _FindingScreenState extends State<FindingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  Timer? _step;
  Timer? _done;
  int _stage = 0;

  static const _stages = [
    'Contacting nearby drivers…',
    'Checking driver verification…',
    'Confirming your pickup…',
  ];

  @override
  void initState() {
    super.initState();
    _step = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (mounted && _stage < _stages.length - 1) setState(() => _stage++);
    });
    _done = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) Navigator.of(context).pushReplacementNamed(R.arriving);
    });
  }

  @override
  void dispose() {
    _radar.dispose();
    _step?.cancel();
    _done?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TR.navy, TR.navyDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.fade(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s.ride.name} · ${TR.le(s.fare)}',
                      style: TS.label.copyWith(
                          color: const Color(0xFFB9CBE2), fontSize: 14)),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: AnimatedBuilder(
                        animation: _radar,
                        builder: (context, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var k = 0; k < 3; k++)
                              Builder(builder: (_) {
                                final v = (_radar.value + k / 3) % 1.0;
                                return Container(
                                  width: 120 + 180 * v,
                                  height: 120 + 180 * v,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: TR.greenBright.fade(0.6 * (1 - v)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              }),
                            Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [TR.greenBright, TR.green],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: TR.greenBright.fade(0.45),
                                      blurRadius: 40),
                                ],
                              ),
                              child: Icon(s.ride.icon,
                                  color: Colors.white, size: 60),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Text('Finding a verified driver',
                        textAlign: TextAlign.center,
                        style: TS.h2.copyWith(color: Colors.white))
                    .animate()
                    .fadeIn(),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_stages[_stage],
                      key: ValueKey(_stage),
                      style: TS.body.copyWith(color: const Color(0xFFB9CBE2))),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.fade(0.07),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const RouteRail(height: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Congo Cross',
                              style: TS.label.copyWith(color: Colors.white)),
                          const SizedBox(height: 14),
                          Text(s.destination.name,
                              style: TS.label.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                TRButton(
                  label: 'Cancel request',
                  kind: BtnKind.light,
                  icon: PhosphorIconsBold.x,
                  onPressed: () {
                    s.cancelTrip();
                    showToast(context, 'Request cancelled — no charge',
                        icon: PhosphorIconsFill.info);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
