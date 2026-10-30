import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';

enum _Phase { idle, request, toPickup, onTrip }

class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({super.key});
  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  Timer? _incoming;
  late final AnimationController _countdown = AnimationController(
      vsync: this, duration: const Duration(seconds: 15))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed && _phase == _Phase.request) {
        _decline(missed: true);
      }
    });

  static const _fare = 85.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppScope.read(context).driverOnline) _scheduleRequest();
    });
  }

  @override
  void dispose() {
    _incoming?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  void _scheduleRequest([int seconds = 4]) {
    _incoming?.cancel();
    _incoming = Timer(Duration(seconds: seconds), () {
      if (!mounted || !AppScope.read(context).driverOnline) return;
      HapticFeedback.heavyImpact();
      setState(() => _phase = _Phase.request);
      _countdown.forward(from: 0);
    });
  }

  void _toggle() {
    final s = AppScope.read(context);
    s.toggleOnline();
    HapticFeedback.mediumImpact();
    if (s.driverOnline) {
      _scheduleRequest();
    } else {
      _incoming?.cancel();
      _countdown.stop();
      setState(() => _phase = _Phase.idle);
    }
  }

  void _decline({bool missed = false}) {
    _countdown.stop();
    setState(() => _phase = _Phase.idle);
    showToast(context, missed ? 'Request missed' : 'Request declined',
        icon: PhosphorIconsFill.info);
    _scheduleRequest(7);
  }

  void _accept() {
    _countdown.stop();
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.toPickup);
  }

  void _startTrip() => setState(() => _phase = _Phase.onTrip);

  void _complete() {
    AppScope.read(context).acceptRide(_fare);
    setState(() => _phase = _Phase.idle);
    showToast(context,
        'Trip complete · you earned ${TR.le(_fare * 0.85, decimals: true)}',
        icon: PhosphorIconsFill.coins);
    _scheduleRequest(8);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mode = switch (_phase) {
      _Phase.toPickup || _Phase.onTrip => MapMode.route,
      _ => MapMode.driver,
    };
    return Stack(
      children: [
        Positioned.fill(
            child: TRMap(mode: mode, showHeat: s.driverOnline && _phase == _Phase.idle)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: TR.shadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: TS.small.copyWith(fontSize: 11)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: s.driverToday),
                      duration: const Duration(milliseconds: 800),
                      builder: (_, v, __) => Text(TR.le(v, decimals: true),
                          style: TS.h3),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CircleIconButton(
                icon: PhosphorIconsBold.userSwitch,
                label: 'Switch to rider app',
                background: Colors.white,
                shadow: true,
                onTap: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(R.rider, (r) => false),
              ),
              const SizedBox(width: 10),
              const Avatar('MS', size: 46, ring: true),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero)
                  .animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: switch (_phase) {
                _Phase.request => _requestPanel(),
                _Phase.toPickup => _tripPanel(pickup: true),
                _Phase.onTrip => _tripPanel(pickup: false),
                _Phase.idle => _idlePanel(s),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _idlePanel(AppState s) {
    final on = s.driverOnline;
    return BottomPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: _toggle,
            semanticLabel: on ? 'Go offline' : 'Go online',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: on
                      ? [TR.navySoft, TR.navy]
                      : [const Color(0xFF239142), TR.green],
                ),
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  BoxShadow(
                      color: (on ? TR.navy : TR.green).fade(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsFill.power, color: Colors.white, size: 24)
                      .animate(target: on ? 1.0 : 0.0)
                      .rotate(end: 0.5),
                  const SizedBox(width: 10),
                  Text(on ? 'You’re online · Go offline' : 'Go online',
                      style: TS.label.copyWith(
                          color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (on)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                      color: TR.greenBright, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 1, duration: 700.ms),
              Flexible(
                child: Text(
                  on
                      ? 'Looking for riders near Congo Cross. Green zones are busy now.'
                      : 'You’re offline. Go online to start receiving trips.',
                  textAlign: TextAlign.center,
                  style: TS.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            _stat('${s.driverTripsToday}', 'Trips today', PhosphorIconsFill.path),
            const SizedBox(width: 8),
            _stat('5h 20m', 'Online', PhosphorIconsFill.timer),
            const SizedBox(width: 8),
            _stat('96%', 'Acceptance', PhosphorIconsFill.thumbsUp),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String v, String l, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: TR.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: TR.green),
              const SizedBox(height: 6),
              Text(v, style: TS.h3.copyWith(fontSize: 17)),
              Text(l, style: TS.small.copyWith(fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _requestPanel() {
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Pill('New TrustRide Car request',
                icon: PhosphorIconsFill.lightning),
            const Spacer(),
            SizedBox(
              width: 52,
              height: 52,
              child: AnimatedBuilder(
                animation: _countdown,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: 1 - _countdown.value,
                        strokeWidth: 4,
                        color: _countdown.value > 0.7 ? TR.danger : TR.green,
                        backgroundColor: TR.line,
                      ),
                    ),
                    Text('${(15 * (1 - _countdown.value)).ceil()}',
                        style: TS.h3),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TR.le(_fare, decimals: true),
                        style: TS.h1.copyWith(color: TR.navy, fontSize: 34)),
                    Text(
                        'You earn ${TR.le(_fare * 0.85, decimals: true)} after commission',
                        style: TS.small),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('4.2 km · 18 min', style: TS.label.copyWith(fontSize: 14)),
                  Text('Pickup 1.1 km away', style: TS.small),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: TR.surface, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const RouteRail(height: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Congo Cross', style: TS.label),
                    Text('Gate on Wilkinson Road', style: TS.small.copyWith(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Lumley Beach Road', style: TS.label),
                    Text('Lumley', style: TS.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Avatar('AK', size: 36, bg: TR.greenTint, fg: TR.green),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Aminata K. · 4.8 rating',
                    style: TS.label.copyWith(fontSize: 14))),
            const Pill('Orange Money', kind: PillKind.warning),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TRButton(
                  label: 'Decline',
                  kind: BtnKind.outline,
                  height: 58,
                  onPressed: _decline),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TRButton(
                  label: 'Accept',
                  icon: PhosphorIconsBold.check,
                  height: 58,
                  onPressed: _accept),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _tripPanel({required bool pickup}) {
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          Row(children: [
            IconBubble(
                pickup ? PhosphorIconsFill.navigationArrow : PhosphorIconsFill.flagCheckered,
                color: Colors.white,
                bg: pickup ? TR.navy : TR.green,
                size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickup ? 'Pick up Aminata' : 'Drop off at Lumley Beach',
                      style: TS.h3),
                  Text(
                      pickup
                          ? 'Congo Cross · 1.1 km · 4 min'
                          : 'Lumley Beach Road · 4.2 km · 18 min',
                      style: TS.small),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (pickup)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: TR.greenTint, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(PhosphorIconsFill.password, color: TR.green),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Ask the rider for their 4-digit ride PIN before starting.',
                        style: TS.small.copyWith(color: TR.ink))),
              ]),
            ),
          const SizedBox(height: 14),
          Row(children: [
            CircleIconButton(
                icon: PhosphorIconsFill.phone,
                label: 'Call rider',
                onTap: () => showToast(context, 'Calling Aminata…',
                    icon: PhosphorIconsFill.phoneCall)),
            const SizedBox(width: 10),
            CircleIconButton(
                icon: PhosphorIconsFill.chatCircleDots,
                label: 'Message rider',
                onTap: () => showToast(context, 'Chat opened',
                    icon: PhosphorIconsFill.chatCircleDots)),
            const SizedBox(width: 12),
            Expanded(
              child: TRButton(
                label: pickup ? 'Start trip (PIN 4827)' : 'Complete trip',
                kind: pickup ? BtnKind.dark : BtnKind.primary,
                height: 54,
                onPressed: pickup ? _startTrip : _complete,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
