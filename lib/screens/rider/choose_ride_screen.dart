import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';

class ChooseRideScreen extends StatefulWidget {
  const ChooseRideScreen({super.key});
  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  bool _booking = false;
  bool _loadingRoute = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = AppScope.read(context);
    setState(() => _loadingRoute = true);
    if (s.pickup == null) await s.locate();
    await s.loadRoute();
    if (mounted) setState(() => _loadingRoute = false);
  }

  Future<void> _book() async {
    final s = AppScope.read(context);
    setState(() => _booking = true);
    try {
      await s.book();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(R.ride, ModalRoute.withName(R.rider));
    } catch (e) {
      if (mounted) {
        showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final h = MediaQuery.of(context).size.height;
    final route = s.route;
    final rides = s.config.enabledRides;
    final wallet = s.profile?.wallet ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.45,
            child: LiveMap(
              pickup: s.pickup?.latLng,
              dropoff: s.dropoff?.latLng,
              route: route?.points ?? const [],
              fitAll: true,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const TRBack(light: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: TR.shadow(),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.flagCheckered,
                          size: 18, color: TR.navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.dropoff?.label ?? 'Destination',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.label.copyWith(fontSize: 14)),
                      ),
                      if (route != null)
                        Text(
                            '${route.distanceKm.toStringAsFixed(1)} km · ${route.durationMin.round()} min',
                            style: TS.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: h * 0.40,
            child: BottomPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text('Choose a ride', style: TS.h3),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _loadingRoute || route == null
                        ? const Loading()
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: rides.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rides[i];
                              final sel = r.id == s.rideId;
                              return SelectTile(
                                selected: sel,
                                onTap: () => s.setRide(r.id),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 54,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: sel ? TR.green : TR.field,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(rideIcon(r.id),
                                        color: sel ? Colors.white : TR.navy,
                                        size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text(r.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TS.label),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(PhosphorIconsFill.user,
                                              size: 12, color: TR.subtle),
                                          Text(' ${r.seats}',
                                              style: TS.small.copyWith(fontSize: 12)),
                                        ]),
                                        Text(r.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TS.small.copyWith(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text(TR.le(s.fareFor(r)),
                                      style: TS.label.copyWith(fontSize: 16)),
                                ]),
                              )
                                  .animate()
                                  .fadeIn(delay: (60 * i).ms)
                                  .slideY(begin: 0.3, curve: Curves.easeOutCubic);
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _payChip(s, 'cash', 'Cash', PhosphorIconsFill.money,
                          TR.green, enabled: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _payChip(
                          s,
                          'wallet',
                          'Wallet · ${TR.le(wallet)}',
                          PhosphorIconsFill.wallet,
                          TR.navy,
                          enabled: wallet >= s.fare && s.fare > 0),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TRButton(
                    label: route == null
                        ? 'Calculating fare…'
                        : 'Book ${s.ride.name} · ${TR.le(s.fare)}',
                    loading: _booking,
                    onPressed: route == null || s.dropoff == null ? null : _book,
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.25, duration: 450.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  Widget _payChip(AppState s, String id, String label, IconData icon, Color c,
      {required bool enabled}) {
    final sel = s.payment == id && enabled;
    if (s.payment == id && !enabled && id == 'wallet') {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.setPayment('cash'));
    }
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SelectTile(
        selected: sel,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        onTap: () {
          if (!enabled) {
            showToast(context, 'Not enough wallet balance for this ride',
                icon: PhosphorIconsFill.wallet);
            return;
          }
          s.setPayment(id);
        },
        child: Row(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TS.label.copyWith(fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
