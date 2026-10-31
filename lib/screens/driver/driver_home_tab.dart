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
import '../chat_screen.dart';

/// Requests within this distance of the driver are shown.
const _requestRadiusKm = 8.0;

class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({super.key});
  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  String? _uid;
  Stream<List<Trip>>? _myTrips;
  Stream<List<Trip>>? _requests;
  StreamSubscription<LatLng>? _gps;
  DateTime _lastSent = DateTime(2000);
  LatLng? _me;
  final Set<String> _hidden = {};
  final Map<String, double> _sent = {}; // tripId -> my price
  final Set<String> _seen = {};
  bool _busy = false;
  bool _toggling = false;

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
        if (d.account.isEmpty) {
          showToast(context, 'Add your payment account first so riders can pay you',
              icon: PhosphorIconsFill.bank);
          Navigator.of(context).pushNamed(R.driverSignup);
          return;
        }
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

  int _etaTo(LatLng p) {
    if (_me == null) return 5;
    final km = GeoService.km(_me!, p);
    return (km * 1.3 / 20 * 60).ceil().clamp(1, 60).toInt();
  }

  /// Sheet where the driver accepts the rider's price or proposes their own.
  Future<void> _offerSheet(Trip t, DriverProfile d) async {
    final c = AppScope.read(context).config.commission;
    final step = t.fare >= 100 ? 10.0 : 5.0;
    var price = _sent[t.id] ?? t.fare;
    final ctrl = TextEditingController(text: price.round().toString());
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) {
          void setPrice(double v) {
            if (v < 1) return;
            price = v.roundToDouble();
            ctrl.text = price.round().toString();
            set(() {});
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
            child: BottomPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 14),
                  Row(children: [
                    Avatar(initialsOf(t.riderName), photo: t.riderPhoto, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your price for ${t.riderName.split(' ').first}', style: TS.h3),
                          Text('${t.distanceKm.toStringAsFixed(1)} km · ${t.durationMin.round()} min · ${t.paymentLabel}',
                              style: TS.small.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    CircleIconButton(
                        icon: PhosphorIconsBold.minus,
                        label: 'Lower',
                        size: 52,
                        onTap: () => setPrice(price - step)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: TS.h1.copyWith(color: TR.navy, fontSize: 32),
                        onChanged: (v) => set(() => price = double.tryParse(v) ?? price),
                        decoration: const InputDecoration(prefixText: 'Le '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleIconButton(
                        icon: PhosphorIconsBold.plus,
                        label: 'Raise',
                        size: 52,
                        onTap: () => setPrice(price + step)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    for (final add in [0.0, step, step * 2, step * 4])
                      ChoiceChip(
                        label: Text(add == 0 ? 'Rider’s ${TR.le(t.fare)}' : '+${TR.le(add)}'),
                        selected: price == t.fare + add,
                        selectedColor: TR.greenTint,
                        onSelected: (_) => setPrice(t.fare + add),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                      'Rider offered ${TR.le(t.fare)} · TrustRide recommends ${TR.le(t.suggestedFare)}\nYou keep ${TR.le(price * (1 - c), decimals: true)} after ${(c * 100).round()}% commission',
                      style: TS.small),
                  const SizedBox(height: 16),
                  TRButton(
                    label: price == t.fare ? 'Accept ${TR.le(price)}' : 'Send offer ${TR.le(price)}',
                    icon: PhosphorIconsBold.paperPlaneTilt,
                    onPressed: price > 0 ? () => Navigator.pop(sheet, price) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await Db.guard(Db.sendOffer(tripId: t.id, d: d, price: result, etaMin: _etaTo(t.pickup.latLng)));
      HapticFeedback.mediumImpact();
      setState(() => _sent[t.id] = result);
      if (mounted) {
        showToast(context, 'Offer sent. Waiting for the rider to choose.',
            icon: PhosphorIconsFill.paperPlaneTilt);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(Trip t, DriverProfile d) async {
    try {
      await Db.withdrawOffer(t.id, d.uid);
      setState(() => _sent.remove(t.id));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
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
        ? Uri.parse('https://www.openstreetmap.org/directions?to=${to.latitude},${to.longitude}')
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
        showToast(context, 'Wrong PIN. Ask the rider to check their app.', icon: PhosphorIconsFill.warning);
      }
      return;
    }
    await _run(() => Db.setTripStatus(t.id, TripStatus.inProgress));
  }

  Future<void> _complete(Trip t) async {
    final cash = t.payment == 'cash';
    final received = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Finish trip · ${TR.le(t.fare)}', style: TS.h3),
        content: Text(
            cash
                ? 'Collect ${TR.le(t.fare)} in cash from ${t.riderName.split(' ').first}.'
                : '${t.riderName.split(' ').first} will transfer ${TR.le(t.fare)} to your ${t.driverAccount.title} account. Confirm when the money arrives.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(cash ? 'Not paid yet' : 'Not received yet',
                  style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(cash ? 'Cash received' : 'Money received',
                  style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    if (received == null) return;
    await _run(() => Db.completeTrip(t.id, paymentReceived: received));
    if (mounted) showToast(context, 'Trip complete · ${TR.le(t.fare)}', icon: PhosphorIconsFill.coins);
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
        final todayNet = today.fold<double>(0, (a, t) => a + t.fare * (1 - s.config.commission) + t.tip);

        if (current != null) {
          return _layout(d, todayNet, current: current, panel: _tripPanel(current));
        }
        return StreamBuilder<List<Trip>>(
          stream: _requests,
          builder: (context, reqSnap) {
            final open = (reqSnap.data ?? const <Trip>[])
                .where((t) =>
                    t.rideType == d.vehicleType &&
                    t.riderId != d.uid &&
                    !_hidden.contains(t.id) &&
                    (_me == null || GeoService.km(_me!, t.pickup.latLng) <= _requestRadiusKm))
                .toList()
              ..sort((a, b) => _me == null
                  ? 0
                  : GeoService.km(_me!, a.pickup.latLng).compareTo(GeoService.km(_me!, b.pickup.latLng)));
            // Forget offers on trips that are no longer open.
            _sent.removeWhere((id, _) => !(reqSnap.data ?? const <Trip>[]).any((t) => t.id == id));
            final fresh = open.where((t) => !_seen.contains(t.id)).toList();
            if (fresh.isNotEmpty) {
              _seen.addAll(fresh.map((t) => t.id));
              WidgetsBinding.instance.addPostFrameCallback((_) => HapticFeedback.heavyImpact());
            }
            final list = wantRequests ? open : const <Trip>[];
            return _layout(d, todayNet,
                preview: list.isEmpty ? null : list.first,
                panel: list.isEmpty ? _idlePanel(d, today.length, todayNet) : _requestsPanel(list, d));
          },
        );
      },
    );
  }

  Widget _layout(DriverProfile d, double todayNet, {Trip? current, Trip? preview, required Widget panel}) {
    final onTrip = current?.status == TripStatus.inProgress;
    final focus = current ?? preview;
    return Stack(
      children: [
        Positioned.fill(
          child: LiveMap(
            me: _me ?? d.location,
            center: focus == null ? (_me ?? d.location) : null,
            pickup: focus == null || onTrip ? null : focus.pickup.latLng,
            dropoff: focus == null ? null : (onTrip || preview != null ? focus.dropoff.latLng : null),
            fitAll: focus != null,
            bottomPadding: 420,
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
                      builder: (_, v, __) => Text(TR.le(v), style: TS.h3),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const LogoMark(size: 46),
              const Spacer(),
              CircleIconButton(
                icon: PhosphorIconsBold.userSwitch,
                label: 'Switch to rider app',
                background: Colors.white,
                shadow: true,
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (_) => false),
              ),
              const SizedBox(width: 8),
              Avatar(d.initials, photo: d.photo, size: 46, ring: true),
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
              key: ValueKey('${current?.id}-${current?.status}-${preview == null}-${d.online}'),
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
                  BoxShadow(color: (on ? TR.navy : TR.green).fade(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: _toggling
                  ? const Center(
                      child: SizedBox(
                          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
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
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 1, duration: 700.ms),
              Flexible(
                child: Text(
                  on
                      ? 'Looking for ${AppScope.read(context).config.ride(d.vehicleType).name} requests within ${_requestRadiusKm.round()} km. You set your own price.'
                      : 'You’re offline. Go online to see ride requests.',
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
            _stat(d.ratingCount == 0 ? 'New' : d.rating.toStringAsFixed(1), 'Rating', PhosphorIconsFill.star),
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

  Widget _requestsPanel(List<Trip> list, DriverProfile d) {
    final h = MediaQuery.of(context).size.height;
    return BottomPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(PhosphorIconsFill.lightning, color: TR.gold, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${list.length} ride request${list.length == 1 ? '' : 's'} nearby', style: TS.h3),
              ),
              TextButton(
                onPressed: _toggling ? null : () => _toggle(d),
                child: Text('Go offline', style: TS.label.copyWith(color: TR.muted, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _requestCard(list[i], d)
                    .animate(key: ValueKey(list[i].id))
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Trip t, DriverProfile d) {
    final s = AppScope.read(context);
    final pickupKm = _me == null ? null : GeoService.km(_me!, t.pickup.latLng);
    final mine = _sent[t.id];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine != null ? TR.greenTint : TR.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mine != null ? TR.green : TR.line),
      ),
      child: Column(children: [
        Row(children: [
          Avatar(initialsOf(t.riderName), photo: t.riderPhoto, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.forSomeoneElse ? '${t.passengerName} (for ${t.riderName.split(' ').first})'
                    : t.riderName.split(' ').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label),
                Text(
                    '${pickupKm == null ? '' : '${pickupKm.toStringAsFixed(1)} km away · '}${t.distanceKm.toStringAsFixed(1)} km trip',
                    style: TS.small.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TR.le(t.fare), style: TS.h2.copyWith(color: TR.navy, fontSize: 22)),
            Pill(t.payment == 'transfer' ? 'Transfer' : 'Cash',
                kind: t.payment == 'transfer' ? PillKind.info : PillKind.warning),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const RouteRail(height: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.pickup.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label.copyWith(fontSize: 13.5)),
              const SizedBox(height: 8),
              Text(t.dropoff.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label.copyWith(fontSize: 13.5)),
            ]),
          ),
        ]),
        if (t.note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(PhosphorIconsFill.chatText, size: 15, color: TR.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(t.note, style: TS.small.copyWith(fontSize: 12.5, color: TR.ink))),
          ]),
        ],
        const SizedBox(height: 12),
        if (mine != null)
          Row(children: [
            const Icon(PhosphorIconsFill.paperPlaneTilt, color: TR.green, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text('You offered ${TR.le(mine)} · waiting for rider',
                  style: TS.label.copyWith(fontSize: 13, color: const Color(0xFF1F6B2E))),
            ),
            TextButton(
                onPressed: () => _offerSheet(t, d),
                child: Text('Change', style: TS.label.copyWith(color: TR.navy, fontSize: 13))),
            TextButton(
                onPressed: () => _withdraw(t, d),
                child: Text('Withdraw', style: TS.label.copyWith(color: TR.danger, fontSize: 13))),
          ])
        else
          Row(children: [
            Expanded(
              child: TRButton(
                label: 'Skip',
                kind: BtnKind.outline,
                height: 48,
                onPressed: () => setState(() => _hidden.add(t.id)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TRButton(
                label: 'Offer your price',
                icon: PhosphorIconsBold.tag,
                height: 48,
                loading: _busy,
                onPressed: () => _offerSheet(t, d),
              ),
            ),
          ]),
        if (s.config.commission > 0 && mine == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('At the rider’s price you keep ${TR.le(t.fare * (1 - s.config.commission))}',
                style: TS.small.copyWith(fontSize: 11.5)),
          ),
      ]),
    );
  }

  Widget _tripPanel(Trip t) {
    final toPickup = t.status == TripStatus.accepted;
    final atPickup = t.status == TripStatus.arrived;
    final onTrip = t.status == TripStatus.inProgress;
    final who = t.forSomeoneElse ? t.passengerName.split(' ').first : t.riderName.split(' ').first;
    final callPhone = t.forSomeoneElse && t.passengerPhone.isNotEmpty ? t.passengerPhone : t.riderPhone;
    final title = toPickup ? 'Pick up $who' : atPickup ? 'Waiting for $who' : 'Drop off at ${t.dropoff.label}';
    final dest = onTrip ? t.dropoff : t.pickup;
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          Row(children: [
            Avatar(initialsOf(t.riderName), photo: t.riderPhoto, size: 50, ring: true),
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
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(TR.le(t.fare), style: TS.h3.copyWith(color: TR.navy)),
              Text(t.payment == 'transfer' ? 'Transfer' : 'Cash', style: TS.small.copyWith(fontSize: 11.5)),
            ]),
          ]),
          if (t.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: TR.amberTint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(PhosphorIconsFill.chatText, color: TR.amberInk, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(t.note, style: TS.small.copyWith(color: TR.ink))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
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
                onTap: () => launchUrl(Uri(scheme: 'tel', path: callPhone))),
            const SizedBox(width: 10),
            CircleIconButton(
                icon: PhosphorIconsFill.chatCircleDots,
                label: 'Chat with rider',
                onTap: () => Navigator.of(context).pushNamed(R.chat,
                    arguments: ChatArgs(
                        tripId: t.id,
                        otherName: t.riderName,
                        otherPhone: t.riderPhone,
                        otherPhoto: t.riderPhoto))),
            const SizedBox(width: 12),
            Expanded(
              child: TRButton(
                label: toPickup
                    ? 'I’ve arrived'
                    : atPickup
                        ? 'Start trip'
                        : 'Complete trip',
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
