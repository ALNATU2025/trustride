import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenTab});
  final ValueChanged<int> onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Stream<List<DriverProfile>> _drivers = Db.onlineDrivers();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).locate();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openSaved(AppState s, String slot, Place? p) {
    if (p == null) {
      Navigator.of(context).pushNamed(R.search, arguments: slot);
      return;
    }
    s.setDropoff(p);
    Navigator.of(context).pushNamed(R.chooseRide);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    final me = s.myLocation;
    final quick = [
      ('car', 'Car'),
      ('keke', 'Keke'),
      ('okada', 'Okada'),
    ].where((q) => s.config.enabledRides.any((r) => r.id == q.$1)).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: StreamBuilder<List<DriverProfile>>(
            stream: _drivers,
            builder: (context, snap) {
              final near = (snap.data ?? const <DriverProfile>[])
                  .where((d) =>
                      me == null || GeoService.km(me, d.location!) < 10)
                  .map((d) => d.location!)
                  .toList();
              return LiveMap(me: me, nearby: near, center: me, bottomPadding: 380);
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                CircleIconButton(
                  icon: PhosphorIconsBold.list,
                  label: 'Account',
                  background: Colors.white,
                  shadow: true,
                  onTap: () => widget.onOpenTab(3),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pushNamed(R.safety),
                  semanticLabel: 'Safety centre',
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: TR.shadow(),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.shieldCheck,
                          color: TR.green, size: 20),
                      const SizedBox(width: 6),
                      Text('Safety', style: TS.label.copyWith(color: TR.green)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                CircleIconButton(
                  icon: PhosphorIconsBold.crosshair,
                  label: 'Find my location',
                  background: Colors.white,
                  shadow: true,
                  onTap: () => s.locate(resetPickup: true),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.5),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomPanel(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 14),
                if (s.currentTripId != null) ...[
                  Pressable(
                    onTap: () => Navigator.of(context).pushNamed(R.ride),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: TR.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(children: [
                        const Icon(PhosphorIconsFill.navigationArrow,
                            color: TR.greenBright),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('You have a ride in progress',
                              style: TS.label.copyWith(color: Colors.white)),
                        ),
                        const Icon(PhosphorIconsBold.arrowRight,
                            color: Colors.white, size: 18),
                      ]),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(
                      delay: 1500.ms,
                      duration: 1200.ms,
                      color: Colors.white.fade(0.25)),
                  const SizedBox(height: 14),
                ],
                Text('${_greeting()},', style: TS.small),
                Text(p == null ? 'Kushɛ' : 'Kushɛ, ${p.firstName}', style: TS.h2),
                if (s.locationError != null) ...[
                  const SizedBox(height: 10),
                  Pressable(
                    onTap: () => s.locate(resetPickup: true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: TR.amberTint,
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(PhosphorIconsFill.warning,
                            color: TR.amberInk, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${s.locationError} Tap to retry.',
                              style: TS.small.copyWith(color: TR.ink)),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Pressable(
                  scale: 0.98,
                  onTap: () => Navigator.of(context)
                      .pushNamed(R.search, arguments: 'dropoff'),
                  semanticLabel: 'Where to?',
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TR.field,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsBold.magnifyingGlass,
                          color: TR.navy, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Where to?',
                            style: TS.label.copyWith(fontSize: 17, color: TR.muted)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < quick.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i < quick.length - 1 ? 10 : 0),
                          child: Pressable(
                            onTap: () {
                              s.setRide(quick[i].$1);
                              Navigator.of(context)
                                  .pushNamed(R.search, arguments: 'dropoff');
                            },
                            semanticLabel: quick[i].$2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: TR.greenTint,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(children: [
                                Icon(rideIcon(quick[i].$1),
                                    color: i == 0 ? TR.navy : TR.green, size: 30),
                                const SizedBox(height: 4),
                                Text(quick[i].$2,
                                    style: TS.label.copyWith(fontSize: 13)),
                              ]),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: (200 + i * 80).ms)
                              .scale(begin: const Offset(0.85, 0.85)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _savedRow(s, 'home', 'Home', PhosphorIconsFill.house, p?.home),
                _savedRow(s, 'work', 'Work', PhosphorIconsFill.briefcase, p?.work),
              ],
            ),
          ).animate().slideY(begin: 0.4, duration: 550.ms, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }

  Widget _savedRow(
      AppState s, String slot, String label, IconData icon, Place? place) {
    return Pressable(
      scale: 0.98,
      onTap: () => _openSaved(s, slot, place),
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          IconBubble(icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TS.label),
                Text(place?.label ?? 'Add $label address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TS.small.copyWith(
                        color: place == null ? TR.navy : TR.muted)),
              ],
            ),
          ),
          Icon(place == null ? PhosphorIconsBold.plus : PhosphorIconsBold.caretRight,
              size: 16, color: TR.subtle),
        ]),
      ),
    );
  }
}
