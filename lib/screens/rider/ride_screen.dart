import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';

/// The rider's live trip, driven entirely by the trip document:
/// requested → accepted → arrived → in_progress → completed (pay) → rate.
class RideScreen extends StatefulWidget {
  const RideScreen({super.key});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen>
    with SingleTickerProviderStateMixin {
  String? _id;
  Stream<Trip?>? _trip;
  String? _driverId;
  Stream<DriverProfile?>? _driver;
  List<LatLng> _route = const [];
  bool _routeLoading = false;
  bool _busy = false;
  bool _leaving = false;
  Timer? _tick;
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _id = s.currentTripId;
    if (_id != null) _trip = Db.tripStream(_id!);
    // Re-evaluate "no drivers found yet" every 15 s.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _radar.dispose();
    super.dispose();
  }

  void _loadRoute(Trip t) {
    if (_route.isNotEmpty || _routeLoading) return;
    final s = AppScope.read(context);
    if (s.route != null && s.dropoff?.lat == t.dropoff.lat) {
      _route = s.route!.points;
      return;
    }
    _routeLoading = true;
    GeoService.route(t.pickup.latLng, t.dropoff.latLng).then((r) {
      if (mounted) setState(() => _route = r.points);
    }).whenComplete(() => _routeLoading = false);
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _share(Trip t) async {
    final s = AppScope.read(context);
    final contacts = s.profile?.contacts ?? const <Contact>[];
    final text =
        'I’m on a TrustRide trip from ${t.pickup.label} to ${t.dropoff.label}. '
        'Driver: ${t.driverName}, plate ${t.driverPlate}, phone ${t.driverPhone}.';
    final to = contacts.map((c) => c.phone).join(',');
    final ok = await launchUrl(
        Uri.parse('sms:$to?body=${Uri.encodeComponent(text)}'));
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showToast(context, 'Trip details copied — paste them to a contact');
    }
  }

  Future<void> _cancel(Trip t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Cancel this ride?', style: TS.h3),
        content: Text(
            t.hasDriver
                ? '${t.driverName} is already on the way.'
                : 'We’ll stop looking for a driver.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Keep ride', style: TS.label.copyWith(color: TR.navy))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Cancel ride', style: TS.label.copyWith(color: TR.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Db.cancelTrip(t.id, 'rider');
      if (!mounted) return;
      _leave();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    AppScope.read(context).finishBooking();
    Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (_) => false);
  }

  Future<void> _rebook() async {
    final s = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final id = await s.book();
      setState(() {
        _id = id;
        _trip = Db.tripStream(id);
        _driverId = null;
        _driver = null;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sos(Trip t) {
    final s = AppScope.read(context);
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
                'We’ll alert the TrustRide safety team with your live location, driver and plate.',
                style: TS.body),
            const SizedBox(height: 16),
            TRButton(
              label: 'Alert TrustRide and call ${s.config.policeNumber}',
              kind: BtnKind.danger,
              icon: PhosphorIconsFill.phoneCall,
              onPressed: () async {
                Navigator.pop(c);
                await _raiseSos(t);
                await _call(s.config.policeNumber);
              },
            ),
            const SizedBox(height: 10),
            TRButton(
              label: 'Alert TrustRide only',
              kind: BtnKind.outline,
              onPressed: () async {
                Navigator.pop(c);
                await _raiseSos(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _raiseSos(Trip t) async {
    final s = AppScope.read(context);
    final p = s.profile;
    if (p == null) return;
    try {
      final at = await LocationService.current();
      await Db.raiseSos(user: p, tripId: t.id, at: at);
      if (mounted) {
        showToast(context, 'Safety team alerted with your location',
            icon: PhosphorIconsFill.siren);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  Future<void> _pay(Trip t, {bool cash = false}) async {
    final s = AppScope.read(context);
    setState(() => _busy = true);
    try {
      if (!cash && t.payment == 'wallet') {
        await Db.payWithWallet(t, s.authUser!.uid);
      } else {
        await Db.markCashPaid(t.id);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const EmptyState(
                  icon: PhosphorIconsFill.carProfile,
                  title: 'No ride in progress'),
              TRButton(label: 'Back to home', expand: false, onPressed: _leave),
            ]),
          ),
        ),
      );
    }
    return StreamBuilder<Trip?>(
      stream: _trip,
      builder: (context, snap) {
        final t = snap.data;
        if (t == null) {
          return const Scaffold(body: Loading());
        }
        if (t.hasDriver && _driverId != t.driverId) {
          _driverId = t.driverId;
          _driver = Db.driverStream(t.driverId);
        }
        if (t.status == TripStatus.completed && t.paid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _leaving) return;
            _leaving = true;
            AppScope.read(context).finishBooking();
            Navigator.of(context).pushNamedAndRemoveUntil(
                R.rate, ModalRoute.withName(R.rider),
                arguments: t.id);
          });
        }
        if (t.status == TripStatus.cancelled && t.cancelledBy != 'driver') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _leave();
          });
        }
        if (t.status == TripStatus.requested) return _finding(t);
        if (t.status == TripStatus.cancelled) return _driverCancelled(t);
        if (t.status == TripStatus.completed) return _payView(t);
        return StreamBuilder<DriverProfile?>(
          stream: _driver,
          builder: (context, dsnap) => _tracking(t, dsnap.data),
        );
      },
    );
  }

  // ---------------- requested ----------------
  Widget _finding(Trip t) {
    final waited = t.createdAt == null
        ? Duration.zero
        : DateTime.now().difference(t.createdAt!);
    final slow = waited.inMinutes >= 4;
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.fade(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${t.rideName} · ${TR.le(t.fare)} · ${t.payment == 'wallet' ? 'Wallet' : 'Cash'}',
                      style: TS.label.copyWith(color: const Color(0xFFB9CBE2), fontSize: 14)),
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
                                  BoxShadow(color: TR.greenBright.fade(0.45), blurRadius: 40),
                                ],
                              ),
                              child: Icon(rideIcon(t.rideType), color: Colors.white, size: 60),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Text(slow ? 'Still looking for a driver' : 'Finding a verified driver',
                        textAlign: TextAlign.center,
                        style: TS.h2.copyWith(color: Colors.white))
                    .animate()
                    .fadeIn(),
                const SizedBox(height: 10),
                Text(
                    slow
                        ? 'Drivers nearby may be busy. You can keep waiting or try another ride type.'
                        : 'Your request has been sent to nearby ${t.rideName} drivers.',
                    textAlign: TextAlign.center,
                    style: TS.body.copyWith(color: const Color(0xFFB9CBE2))),
                const SizedBox(height: 22),
                _routeCard(t, dark: true),
                const SizedBox(height: 18),
                TRButton(
                  label: 'Cancel request',
                  kind: BtnKind.light,
                  icon: PhosphorIconsBold.x,
                  onPressed: () => _cancel(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeCard(Trip t, {bool dark = false}) {
    final fg = dark ? Colors.white : TR.ink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.white.fade(0.07) : TR.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const RouteRail(height: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.pickup.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TS.label.copyWith(color: fg)),
              const SizedBox(height: 14),
              Text(t.dropoff.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TS.label.copyWith(color: fg)),
            ],
          ),
        ),
      ]),
    );
  }

  // ---------------- driver cancelled ----------------
  Widget _driverCancelled(Trip t) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyState(
                  icon: PhosphorIconsFill.info,
                  title: 'Your driver cancelled',
                  body: 'Sorry about that. You weren’t charged. Find another driver?',
                ),
                TRButton(label: 'Find another driver', loading: _busy, onPressed: _rebook),
                const SizedBox(height: 10),
                TRButton(label: 'Back to home', kind: BtnKind.outline, onPressed: _leave),
              ],
            ),
          ),
        ),
      );

  // ---------------- accepted / arrived / in progress ----------------
  Widget _tracking(Trip t, DriverProfile? d) {
    final s = AppScope.read(context);
    final onTrip = t.status == TripStatus.inProgress;
    final arrived = t.status == TripStatus.arrived;
    if (onTrip) _loadRoute(t);
    final driverAt = d?.location;
    final target = onTrip ? t.dropoff.latLng : t.pickup.latLng;
    final km = driverAt == null ? null : GeoService.km(driverAt, target);
    final mins = km == null ? null : (km * 1.3 / 20 * 60).ceil().clamp(1, 120).toInt();

    final title = onTrip
        ? 'Heading to ${t.dropoff.label}'
        : arrived
            ? 'Your driver is here'
            : mins == null
                ? 'Driver on the way'
                : 'Arriving in $mins min';
    final sub = onTrip
        ? (mins == null ? 'Enjoy your ride' : 'About $mins min to go')
        : arrived
            ? 'Look for ${t.driverPlate} and share your PIN'
            : 'Meet at ${t.pickup.label}';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LiveMap(
              pickup: onTrip ? null : t.pickup.latLng,
              dropoff: onTrip ? t.dropoff.latLng : null,
              driver: driverAt,
              route: onTrip ? _route : const [],
              fitAll: true,
              bottomPadding: 360,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                TRBack(light: true, onTap: () => Navigator.of(context).maybePop()),
                const Spacer(),
                Pressable(
                  onTap: () => _sos(t),
                  semanticLabel: 'SOS emergency',
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: TR.danger,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: TR.danger.fade(0.4), blurRadius: 18, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.siren, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text('SOS', style: TS.label.copyWith(color: Colors.white, fontSize: 16)),
                    ]),
                  ),
                ),
              ]),
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
                          key: ValueKey(title),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TS.h2.copyWith(fontSize: 21)),
                            Text(sub, style: TS.small),
                          ],
                        ),
                      ),
                    ),
                    if (!onTrip)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: TR.brandGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(children: [
                          Text('RIDE PIN',
                              style: TS.caps.copyWith(color: const Color(0xFFB9CBE2), fontSize: 10)),
                          Text(t.pin,
                              style: TS.h3.copyWith(color: Colors.white, letterSpacing: 3)),
                        ]),
                      ).animate(target: arrived ? 1.0 : 0.0).shake(hz: 3, duration: 600.ms),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: TR.surface, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Avatar(t.driverInitials, size: 54, ring: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.driverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TS.label.copyWith(fontSize: 16)),
                            Row(children: [
                              const Icon(PhosphorIconsFill.star, color: TR.gold, size: 14),
                              Text(' ${(d?.rating ?? t.driverRating).toStringAsFixed(1)}',
                                  style: TS.small),
                            ]),
                            const Pill('Verified driver', icon: PhosphorIconsFill.sealCheck),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: TR.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(t.driverPlate,
                                style: TS.label.copyWith(letterSpacing: 1)),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 110,
                            child: Text(t.driverVehicle,
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TS.small.copyWith(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _action(PhosphorIconsFill.phone, 'Call', () => _call(t.driverPhone)),
                    const SizedBox(width: 10),
                    _action(PhosphorIconsFill.chatCircleDots, 'SMS',
                        () => launchUrl(Uri.parse('sms:${t.driverPhone}'))),
                    const SizedBox(width: 10),
                    _action(PhosphorIconsFill.shareNetwork, 'Share trip', () => _share(t)),
                  ]),
                  const SizedBox(height: 12),
                  if (!onTrip)
                    TRButton(
                      label: 'Cancel ride',
                      kind: BtnKind.outline,
                      height: 50,
                      onPressed: () => _cancel(t),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: TR.greenTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(t.payment == 'wallet' ? PhosphorIconsFill.wallet : PhosphorIconsFill.money,
                            color: TR.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '${TR.le(t.fare)} · ${t.payment == 'wallet' ? 'paid from wallet at drop-off' : 'pay cash at drop-off'}',
                              style: TS.small.copyWith(color: TR.ink)),
                        ),
                      ]),
                    ),
                  if (s.profile?.contacts.isEmpty ?? true) ...[
                    const SizedBox(height: 8),
                    Text('Tip: add a trusted contact in the Safety centre so you can share trips.',
                        style: TS.small.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ).animate().slideY(begin: 0.3, duration: 450.ms, curve: Curves.easeOutCubic),
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

  // ---------------- completed: pay ----------------
  Widget _payView(Trip t) {
    final s = AppScope.of(context);
    final wallet = t.payment == 'wallet';
    final balance = s.profile?.wallet ?? 0;
    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [TR.greenBright, TR.green]),
                  boxShadow: [BoxShadow(color: TR.green.fade(0.35), blurRadius: 30)],
                ),
                child: const Icon(PhosphorIconsBold.check, color: Colors.white, size: 38),
              ).animate().scale(duration: 700.ms, curve: Curves.elasticOut),
            ),
            const SizedBox(height: 14),
            Center(child: Text('You’ve arrived', style: TS.h2)),
            Center(
              child: Text('${t.dropoff.label} · ${dateLabel(t.completedAt)}',
                  textAlign: TextAlign.center, style: TS.small),
            ),
            const SizedBox(height: 22),
            TRCard(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total', style: TS.label.copyWith(color: TR.muted)),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: t.fare),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(TR.le(v, decimals: true),
                          style: TS.h1.copyWith(color: TR.navy)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: TR.line, height: 1),
                const SizedBox(height: 12),
                _line('Ride', t.rideName),
                _line('Distance', '${t.distanceKm.toStringAsFixed(1)} km'),
                _line('Estimated time', '${t.durationMin.round()} min'),
                _line('Driver', '${t.driverName} · ${t.driverPlate}'),
                _line('Payment', wallet ? 'TrustRide Wallet' : 'Cash to driver'),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
            const SizedBox(height: 16),
            if (wallet && balance < t.fare)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: TR.amberTint, borderRadius: BorderRadius.circular(14)),
                child: Text(
                    'Your wallet has ${TR.le(balance, decimals: true)}. Please pay ${t.driverName} in cash instead.',
                    style: TS.small.copyWith(color: TR.ink)),
              ),
            if (wallet && balance >= t.fare)
              TRButton(
                label: 'Pay ${TR.le(t.fare, decimals: true)} from wallet',
                icon: PhosphorIconsFill.lockSimple,
                loading: _busy,
                onPressed: () => _pay(t),
              )
            else
              TRButton(
                label: 'I paid ${TR.le(t.fare)} in cash',
                icon: PhosphorIconsFill.money,
                loading: _busy,
                onPressed: () => _pay(t, cash: true),
              ),
            const SizedBox(height: 10),
            Text(
                wallet
                    ? 'The fare is taken from your TrustRide Wallet.'
                    : 'Hand the fare to your driver, then confirm here.',
                textAlign: TextAlign.center,
                style: TS.small.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(a, style: TS.small.copyWith(fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(b,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TS.label.copyWith(fontSize: 14)),
          ),
        ]),
      );
}
