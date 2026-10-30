import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Requests within this distance of the driver are offered.
const _requestRadiusKm = 8.0;

class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({super.key});
  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab>
    with SingleTickerProviderStateMixin {
  String? _uid;
  Stream<List<Trip>>? _myTrips;
  Stream<List<Trip>>? _requests;
  StreamSubscription<LatLng>? _gps;
  DateTime _lastSent = DateTime(2000);
  LatLng? _me;
  final Set<String> _declined = {};
  String? _offeredId;
  bool _busy = false;
  bool _toggling = false;

  late final AnimationController _countdown = AnimationController(
      vsync: this, duration: const Duration(seconds: 20))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed && _offeredId != null) {
        setState(() => _declined.add(_offeredId!));
      }
    });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await LocationService.current();
      if (mounted && p != null) setState(() => _me = p);
      if (!mounted) return;
      final d = AppScope.read(context).driver;
      if (d != null && d.online) _startGps(d.uid);
    });
  }

  @override
  void dispose() {
    _gps?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  void _startGps(String uid) {
    _gps?.cancel();
    _gps = LocationService.watch().listen((p) {
      if (!mounted) return;
      setState(() => _me = p);
      if (DateTime.now().difference(_lastSent).inSeconds >= 8) {
        _lastSent = DateTime.now();
        Db.updateLocation(uid, p).catchError((_) {});
      }
    }, onError: (_) {});
  }

  Future<void> _toggle(DriverProfile d) async {
    setState(() => _toggling = true);
    try {
      if (d.online) {
        _gps?.cancel();
        await Db.setOnline(d.uid, false);
      } else {
        final err = await LocationService.ensurePermission();
        if (err != null) {
          if (mounted) showToast(context, err, icon: PhosphorIconsFill.warning);
          return;
        }
        final p = await LocationService.current();
        if (p == null) {
          if (mounted) {
            showToast(context, 'Couldn’t get your location. Try again outdoors.',
                icon: PhosphorIconsFill.warning);
          }
          return;
        }
        _me = p;
        await Db.setOnline(d.uid, true, p);
        _startGps(d.uid);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _accept(Trip t, DriverProfile d) async {
    _countdown.stop();
    setState(() => _busy = true);
    try {
      await Db.acceptTrip(t.id, d);
      HapticFeedback.heavyImpact();
    } catch (e) {
      _declined.add(t.id);
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.info);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate(LatLng to) async {
    final uri = kIsWeb
        ? Uri.parse(
            'https://www.openstreetmap.org/directions?to=${to.latitude},${to.longitude}')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse('geo:${to.latitude},${to.longitude}?q=${to.latitude},${to.longitude}'));
    }
  }

  Future<void> _startWithPin(Trip t) async {
    if (!t.requirePin) {
      await _run(() => Db.setTripStatus(t.id, TripStatus.inProgress));
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Enter the rider’s PIN', style: TS.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: TS.h2.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(counterText: '', hintText: '••••'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Start trip', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    final pin = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (pin != t.pin) {
      if (mounted) {
        showToast(context, 'Wrong PIN. Ask the rider to check their app.',
            icon: PhosphorIconsFill.warning);
      }
      return;
    }
    await _run(() => Db.setTripStatus(t.id, TripStatus.inProgress));
  }

  Future<void> _complete(Trip t) async {
    final cash = t.payment == 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(cash ? 'Collect ${TR.le(t.fare)} cash' : 'Finish this trip?', style: TS.h3),
        content: Text(
            cash
                ? 'Confirm you received ${TR.le(t.fare)} in cash from ${t.riderName}.'
                : 'The rider pays ${TR.le(t.fare)} from their TrustRide Wallet.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Not yet', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(cash ? 'Cash received' : 'Complete',
                  style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => Db.completeTrip(t.id, cashCollected: cash));
    if (mounted) {
      showToast(context, 'Trip complete · ${TR.le(t.fare)}', icon: PhosphorIconsFill.coins);
    }
  }

  Future<void> _driverCancel(Trip t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Cancel this trip?', style: TS.h3),
        content: Text('The rider will be asked to find another driver. Frequent cancellations affect your account.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Keep trip', style: TS.label.copyWith(color: TR.navy))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Cancel trip', style: TS.label.copyWith(color: TR.danger))),
        ],
      ),
    );
    if (ok == true) await _run(() => Db.cancelTrip(t.id, 'driver'));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.driver;
    if (d == null) return const Loading();
    if (_uid != d.uid) {
      _uid = d.uid;
      _myTrips = Db.driverTrips(d.uid);
    }
    final wantRequests = d.online && d.approved;
    if (wantRequests && _requests == null) _requests = Db.openRequests();
    if (!wantRequests) _requests = null;

    return StreamBuilder<List<Trip>>(
      stream: _myTrips,
      builder: (context, mySnap) {
        final mine = mySnap.data ?? const <Trip>[];
        final active = mine.where((t) => t.isActive).toList();
        final current = active.isEmpty ? null : active.first;
        final now = DateTime.now();
        final today = mine.where((t) =>
            t.status == TripStatus.completed &&
            t.completedAt != null &&
            t.completedAt!.year == now.year &&
            t.completedAt!.month == now.month &&
            t.completedAt!.day == now.day);
        final todayNet = today.fold<double>(
            0, (a, t) => a + t.fare * (1 - s.config.commission) + t.tip);

        if (current != null) {
          return _layout(d, todayNet, current: current, panel: _tripPanel(current));
        }
        return StreamBuilder<List<Trip>>(
          stream: _requests,
          builder: (context, reqSnap) {
            final offers = (reqSnap.data ?? const <Trip>[])
                .where((t) =>
                    t.rideType == d.vehicleType &&
                    t.riderId != d.uid &&
                    !_declined.contains(t.id) &&
                    (_me == null || GeoService.km(_me!, t.pickup.latLng) <= _requestRadiusKm))
                .toList()
              ..sort((a, b) => _me == null
                  ? 0
                  : GeoService.km(_me!, a.pickup.latLng)
                      .compareTo(GeoService.km(_me!, b.pickup.latLng)));
            final offer = wantRequests && offers.isNotEmpty ? offers.first : null;
            if (offer?.id != _offeredId) {
              _offeredId = offer?.id;
              if (offer != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  HapticFeedback.heavyImpact();
                  _countdown.forward(from: 0);
                });
              }
            }
            return _layout(d, todayNet,
                offer: offer,
                panel: offer != null
                    ? _requestPanel(offer, d)
                    : _idlePanel(d, today.length, todayNet));
          },
        );
      },
    );
  }

  Widget _layout(DriverProfile d, double todayNet,
      {Trip? current, Trip? offer, required Widget panel}) {
    final onTrip = current?.status == TripStatus.inProgress;
    final focus = current ?? offer;
    return Stack(
      children: [
        Positioned.fill(
          child: LiveMap(
            me: _me ?? d.location,
            center: focus == null ? (_me ?? d.location) : null,
            pickup: focus == null || onTrip ? null : focus.pickup.latLng,
            dropoff: focus == null ? null : (onTrip || offer != null ? focus.dropoff.latLng : null),
            fitAll: focus != null,
            bottomPadding: 380,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      tween: Tween(begin: 0, end: todayNet),
                      duration: const Duration(milliseconds: 800),
                      builder: (_, v, __) => Text(TR.le(v, decimals: true), style: TS.h3),
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
                    .pushNamedAndRemoveUntil(R.rider, (_) => false),
              ),
              const SizedBox(width: 10),
              Avatar(d.initials, size: 46, ring: true),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: KeyedSubtree(
              key: ValueKey('${current?.id}-${current?.status}-${offer?.id}-${d.online}'),
              child: panel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _idlePanel(DriverProfile d, int tripsToday, double todayNet) {
    final on = d.online;
    if (!d.approved) {
      return BottomPanel(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const EmptyState(
            icon: PhosphorIconsFill.hourglassMedium,
            title: 'Waiting for approval',
            body: 'You can go online once our team approves your documents.',
          ),
          TRButton(
              label: 'View application',
              kind: BtnKind.outline,
              onPressed: () => Navigator.of(context).pushNamed(R.driverSignup)),
        ]),
      );
    }
    return BottomPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: _toggling ? null : () => _toggle(d),
            semanticLabel: on ? 'Go offline' : 'Go online',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: on ? [TR.navySoft, TR.navy] : [const Color(0xFF239142), TR.green],
                ),
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  BoxShadow(
                      color: (on ? TR.navy : TR.green).fade(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: _toggling
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsFill.power, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Text(on ? 'You’re online · Go offline' : 'Go online',
                            style: TS.label.copyWith(color: Colors.white, fontSize: 18)),
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
                  decoration: const BoxDecoration(color: TR.greenBright, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 1, duration: 700.ms),
              Flexible(
                child: Text(
                  on
                      ? 'Looking for ${AppScope.read(context).config.ride(d.vehicleType).name} requests within ${_requestRadiusKm.round()} km. Keep the app open.'
                      : 'You’re offline. Go online to receive ride requests.',
                  textAlign: TextAlign.center,
                  style: TS.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            _stat('$tripsToday', 'Trips today', PhosphorIconsFill.path),
            const SizedBox(width: 8),
            _stat(TR.le(todayNet), 'Earned today', PhosphorIconsFill.coins),
            const SizedBox(width: 8),
            _stat(d.ratingCount == 0 ? 'New' : d.rating.toStringAsFixed(1), 'Rating',
                PhosphorIconsFill.star),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String v, String l, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TR.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: TR.green),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(v, style: TS.h3.copyWith(fontSize: 17)),
              ),
              Text(l, style: TS.small.copyWith(fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _requestPanel(Trip t, DriverProfile d) {
    final s = AppScope.read(context);
    final pickupKm = _me == null ? null : GeoService.km(_me!, t.pickup.latLng);
    final net = t.fare * (1 - s.config.commission);
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Pill('New ${t.rideName} request', icon: PhosphorIconsFill.lightning),
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
                    Text('${(20 * (1 - _countdown.value)).ceil()}', style: TS.h3),
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
                    Text(TR.le(t.fare, decimals: true),
                        style: TS.h1.copyWith(color: TR.navy, fontSize: 34)),
                    Text('You earn ${TR.le(net, decimals: true)} after commission',
                        style: TS.small),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${t.distanceKm.toStringAsFixed(1)} km · ${t.durationMin.round()} min',
                      style: TS.label.copyWith(fontSize: 14)),
                  if (pickupKm != null)
                    Text('Pickup ${pickupKm.toStringAsFixed(1)} km away', style: TS.small),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _routeBox(t),
          const SizedBox(height: 12),
          Row(children: [
            Avatar(t.riderName.isEmpty ? '?' : t.riderName[0].toUpperCase(),
                size: 36, bg: TR.greenTint, fg: TR.green),
            const SizedBox(width: 10),
            Expanded(
                child: Text(t.riderName.split(' ').first,
                    style: TS.label.copyWith(fontSize: 14))),
            Pill(t.payment == 'wallet' ? 'Wallet' : 'Cash',
                kind: t.payment == 'wallet' ? PillKind.info : PillKind.warning),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TRButton(
                  label: 'Decline',
                  kind: BtnKind.outline,
                  height: 58,
                  onPressed: () {
                    _countdown.stop();
                    setState(() => _declined.add(t.id));
                  }),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TRButton(
                  label: 'Accept',
                  icon: PhosphorIconsBold.check,
                  height: 58,
                  loading: _busy,
                  onPressed: () => _accept(t, d)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _routeBox(Trip t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: TR.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const RouteRail(height: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.pickup.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label),
                Text(t.pickup.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.small.copyWith(fontSize: 12)),
                const SizedBox(height: 8),
                Text(t.dropoff.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label),
                Text(t.dropoff.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.small.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ]),
      );

  Widget _tripPanel(Trip t) {
    final toPickup = t.status == TripStatus.accepted;
    final atPickup = t.status == TripStatus.arrived;
    final onTrip = t.status == TripStatus.inProgress;
    final title = toPickup
        ? 'Pick up ${t.riderName.split(' ').first}'
        : atPickup
            ? 'Waiting for ${t.riderName.split(' ').first}'
            : 'Drop off at ${t.dropoff.label}';
    final dest = onTrip ? t.dropoff : t.pickup;
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          Row(children: [
            IconBubble(onTrip ? PhosphorIconsFill.flagCheckered : PhosphorIconsFill.navigationArrow,
                color: Colors.white, bg: onTrip ? TR.green : TR.navy, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TS.h3),
                  Text(dest.address.isEmpty ? dest.label : dest.address,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.small),
                ],
              ),
            ),
            Text(TR.le(t.fare), style: TS.h3.copyWith(color: TR.navy)),
          ]),
          const SizedBox(height: 14),
          if (!atPickup)
            TRButton(
              label: onTrip ? 'Navigate to drop-off' : 'Navigate to pickup',
              kind: BtnKind.outline,
              height: 50,
              icon: PhosphorIconsBold.navigationArrow,
              onPressed: () => _navigate(dest.latLng),
            ),
          if (atPickup)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: TR.greenTint, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(PhosphorIconsFill.password, color: TR.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      t.requirePin
                          ? 'Ask the rider for their 4-digit ride PIN to start.'
                          : 'Confirm the rider’s name before starting.',
                      style: TS.small.copyWith(color: TR.ink)),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            CircleIconButton(
                icon: PhosphorIconsFill.phone,
                label: 'Call rider',
                onTap: () => launchUrl(Uri(scheme: 'tel', path: t.riderPhone))),
            const SizedBox(width: 10),
            CircleIconButton(
                icon: PhosphorIconsFill.chatCircleDots,
                label: 'SMS rider',
                onTap: () => launchUrl(Uri.parse('sms:${t.riderPhone}'))),
            const SizedBox(width: 12),
            Expanded(
              child: TRButton(
                label: toPickup
                    ? 'I’ve arrived'
                    : atPickup
                        ? 'Start trip'
                        : (t.payment == 'cash' ? 'Complete · collect cash' : 'Complete trip'),
                kind: onTrip ? BtnKind.primary : BtnKind.dark,
                height: 54,
                loading: _busy,
                onPressed: () {
                  if (toPickup) {
                    _run(() => Db.setTripStatus(t.id, TripStatus.arrived));
                  } else if (atPickup) {
                    _startWithPin(t);
                  } else {
                    _complete(t);
                  }
                },
              ),
            ),
          ]),
          if (!onTrip) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => _driverCancel(t),
                child: Text('Cancel trip', style: TS.label.copyWith(color: TR.danger, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
