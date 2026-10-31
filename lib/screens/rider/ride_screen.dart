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
import '../chat_screen.dart';

/// The rider's live trip, driven by the trip document:
/// requested (drivers send prices) → accepted → arrived → in_progress →
/// completed (pay) → rate.
class RideScreen extends StatefulWidget {
  const RideScreen({super.key});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> with SingleTickerProviderStateMixin {
  Stream<Trip?>? _trip;
  Stream<List<Offer>>? _offers;
  String? _driverId;
  Stream<DriverProfile?>? _driver;
  List<LatLng> _route = const [];
  bool _routeLoading = false;
  bool _busy = false;
  String? _accepting;
  bool _leaving = false;
  int _seenOffers = 0;
  Timer? _tick;
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void initState() {
    super.initState();
    _bind(AppScope.read(context).currentTripId);
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _bind(String? id) {
    _trip = id == null ? null : Db.tripStream(id);
    _offers = id == null ? null : Db.offersStream(id);
    _driverId = null;
    _driver = null;
    _seenOffers = 0;
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

  void _chat(Trip t) => Navigator.of(context).pushNamed(R.chat,
      arguments: ChatArgs(
          tripId: t.id,
          otherName: t.driverName,
          otherPhone: t.driverPhone,
          otherPhoto: t.driverPhoto));

  Future<void> _share(Trip t) async {
    final s = AppScope.read(context);
    final contacts = s.profile?.contacts ?? const <Contact>[];
    final text =
        'I’m on a TrustRide trip from ${t.pickup.label} to ${t.dropoff.label}. '
        'Driver: ${t.driverName}, plate ${t.driverPlate}, phone ${t.driverPhone}.';
    final to = contacts.map((c) => c.phone).join(',');
    final ok = await launchUrl(Uri.parse('sms:$to?body=${Uri.encodeComponent(text)}'));
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
            t.hasDriver ? '${t.driverName} is already on the way.' : 'We’ll stop looking for a driver.',
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
      if (mounted) _leave();
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
      setState(() => _bind(id));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Trip t, Offer o) async {
    setState(() => _accepting = o.driverId);
    try {
      await Db.acceptOffer(t.id, o);
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  Future<void> _raise(Trip t, double by) async {
    try {
      await Db.updateRiderOffer(t.id, t.fare + by);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
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
              const IconBubble(PhosphorIconsFill.siren, color: TR.danger, bg: TR.dangerTint, size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text('Emergency assistance', style: TS.h3)),
            ]),
            const SizedBox(height: 10),
            Text('We’ll alert the TrustRide safety team with your live location, driver and plate.',
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
    final p = AppScope.read(context).profile;
    if (p == null) return;
    try {
      final at = await LocationService.current();
      await Db.raiseSos(user: p, tripId: t.id, at: at);
      if (mounted) {
        showToast(context, 'Safety team alerted with your location', icon: PhosphorIconsFill.siren);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  Future<void> _markPaid(Trip t) async {
    setState(() => _busy = true);
    try {
      await Db.markPaid(t.id);
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
              const EmptyState(icon: PhosphorIconsFill.carProfile, title: 'No ride in progress'),
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
        if (t == null) return const Scaffold(body: Loading());
        if (t.hasDriver && _driverId != t.driverId) {
          _driverId = t.driverId;
          _driver = Db.driverStream(t.driverId);
        }
        if (t.status == TripStatus.completed && t.paid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _leaving) return;
            _leaving = true;
            AppScope.read(context).finishBooking();
            Navigator.of(context).pushNamedAndRemoveUntil(R.rate, ModalRoute.withName(R.rider),
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

  // ---------------- requested: drivers send prices ----------------
  Widget _finding(Trip t) {
    final waited = t.createdAt == null ? Duration.zero : DateTime.now().difference(t.createdAt!);
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
          child: StreamBuilder<List<Offer>>(
            stream: _offers,
            builder: (context, snap) {
              final offers = snap.data ?? const <Offer>[];
              if (offers.length > _seenOffers) {
                _seenOffers = offers.length;
                HapticFeedback.mediumImpact();
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(offers.isEmpty ? 'Finding drivers' : 'Choose your driver',
                                style: TS.h2.copyWith(color: Colors.white)),
                            Text('${t.rideName} · to ${t.dropoff.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TS.small.copyWith(color: const Color(0xFFB9CBE2))),
                          ],
                        ),
                      ),
                      const LogoMark(size: 46),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (offers.isEmpty)
                    Expanded(child: _radarView(t, waited))
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: offers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _offerCard(t, offers[i], best: i == 0)
                            .animate(key: ValueKey(offers[i].driverId))
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: 0.2, curve: Curves.easeOutCubic),
                      ),
                    ),
                  _yourOfferBar(t, offers.length),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _radarView(Trip t, Duration waited) {
    final slow = waited.inMinutes >= 3;
    return Column(children: [
      Expanded(
        child: Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: _radar,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (var k = 0; k < 3; k++)
                    Builder(builder: (_) {
                      final v = (_radar.value + k / 3) % 1.0;
                      return Container(
                        width: 110 + 150 * v,
                        height: 110 + 150 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: TR.greenBright.fade(0.6 * (1 - v)), width: 2),
                        ),
                      );
                    }),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [TR.greenBright, TR.green]),
                      boxShadow: [BoxShadow(color: TR.greenBright.fade(0.45), blurRadius: 40)],
                    ),
                    child: Icon(rideIcon(t.rideType), color: Colors.white, size: 54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
            slow
                ? 'No offers yet. Drivers may be busy — try raising your price a little.'
                : 'Nearby drivers are seeing your request. Their prices will appear here.',
            textAlign: TextAlign.center,
            style: TS.body.copyWith(color: const Color(0xFFB9CBE2))),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _offerCard(Trip t, Offer o, {required bool best}) {
    final busy = _accepting == o.driverId;
    final diff = o.price - t.fare;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: best ? Border.all(color: TR.greenBright, width: 2) : null,
        boxShadow: TR.shadow(),
      ),
      child: Column(children: [
        Row(children: [
          Avatar(o.initials, photo: o.driverPhoto, size: 54, ring: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(o.driverName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label.copyWith(fontSize: 16)),
                  ),
                  if (best) ...[
                    const SizedBox(width: 6),
                    const Pill('Best price', icon: PhosphorIconsFill.sparkle),
                  ],
                ]),
                Row(children: [
                  const Icon(PhosphorIconsFill.star, color: TR.gold, size: 14),
                  Text(
                      o.ratingCount == 0
                          ? ' New driver'
                          : ' ${o.rating.toStringAsFixed(1)} (${o.ratingCount})',
                      style: TS.small.copyWith(fontSize: 12.5)),
                  const SizedBox(width: 8),
                  const Icon(PhosphorIconsFill.clock, color: TR.subtle, size: 13),
                  Text(' ${o.etaMin} min away', style: TS.small.copyWith(fontSize: 12.5)),
                ]),
                Text('${o.vehicle} · ${o.plate}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.small.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TR.le(o.price), style: TS.h2.copyWith(color: TR.navy, fontSize: 22)),
            Text(
                diff == 0
                    ? 'Your price'
                    : diff > 0
                        ? '+${TR.le(diff)}'
                        : '−${TR.le(-diff)}',
                style: TS.small.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: diff > 0 ? TR.amberInk : const Color(0xFF1F6B2E))),
          ]),
        ]),
        const SizedBox(height: 12),
        TRButton(
          label: 'Accept ${TR.le(o.price)}',
          icon: PhosphorIconsBold.check,
          height: 48,
          loading: busy,
          onPressed: _accepting == null ? () => _accept(t, o) : null,
        ),
      ]),
    );
  }

  Widget _yourOfferBar(Trip t, int count) {
    final step = t.suggestedFare >= 100 ? 10.0 : 5.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.fade(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.fade(0.1)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your offer · ${t.payment == 'transfer' ? 'Transfer' : 'Cash'}',
                    style: TS.small.copyWith(color: const Color(0xFFB9CBE2), fontSize: 12)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(TR.le(t.fare),
                      key: ValueKey(t.fare), style: TS.h2.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
          TRButton(
            label: '+${TR.le(step)}',
            kind: BtnKind.light,
            expand: false,
            height: 44,
            onPressed: () => _raise(t, step),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(PhosphorIconsFill.users, color: TR.greenBright.fade(0.9), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                count == 0 ? 'Waiting for drivers…' : '$count driver${count == 1 ? '' : 's'} responded',
                style: TS.small.copyWith(color: const Color(0xFFD6E2F0))),
          ),
          TextButton.icon(
            onPressed: () => _cancel(t),
            icon: const Icon(PhosphorIconsBold.x, color: Colors.white, size: 16),
            label: Text('Cancel', style: TS.label.copyWith(color: Colors.white, fontSize: 14)),
          ),
        ]),
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
                const LogoMark(size: 60),
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
            ? 'Look for ${t.driverPlate}${t.requirePin ? ' and share your PIN' : ''}'
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
              bottomPadding: 380,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                TRBack(light: true, onTap: () => Navigator.of(context).maybePop()),
                const Spacer(),
                const LogoMark(size: 46),
                const Spacer(),
                Pressable(
                  onTap: () => _sos(t),
                  semanticLabel: 'SOS emergency',
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TR.danger,
                      borderRadius: BorderRadius.circular(23),
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
                    if (!onTrip && t.requirePin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: TR.brandGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(children: [
                          Text('RIDE PIN',
                              style: TS.caps.copyWith(color: const Color(0xFFB9CBE2), fontSize: 10)),
                          Text(t.pin, style: TS.h3.copyWith(color: Colors.white, letterSpacing: 3)),
                        ]),
                      ).animate(target: arrived ? 1.0 : 0.0).shake(hz: 3, duration: 600.ms),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: TR.surface, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Avatar(t.driverInitials, photo: d?.photo ?? t.driverPhoto, size: 58, ring: true),
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
                              Text(' ${(d?.rating ?? t.driverRating).toStringAsFixed(1)}', style: TS.small),
                              const SizedBox(width: 8),
                              Text(TR.le(t.fare),
                                  style: TS.label.copyWith(color: TR.navy, fontSize: 14)),
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
                            child: Text(t.driverPlate, style: TS.label.copyWith(letterSpacing: 1)),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 104,
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
                    _action(PhosphorIconsFill.chatCircleDots, 'Chat', () => _chat(t)),
                    const SizedBox(width: 10),
                    _action(PhosphorIconsFill.shareNetwork, 'Share', () => _share(t)),
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
                      decoration: BoxDecoration(color: TR.greenTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(t.payment == 'transfer' ? PhosphorIconsFill.bank : PhosphorIconsFill.money,
                            color: TR.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '${TR.le(t.fare)} · ${t.payment == 'transfer' ? 'transfer to your driver at drop-off' : 'pay cash at drop-off'}',
                              style: TS.small.copyWith(color: TR.ink)),
                        ),
                      ]),
                    ),
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

  // ---------------- completed: pay the driver ----------------
  Widget _payView(Trip t) {
    final transfer = t.payment == 'transfer';
    final acc = t.driverAccount;
    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Align(alignment: Alignment.centerRight, child: LogoMark()),
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
            const SizedBox(height: 20),
            TRCard(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Total to pay', style: TS.label.copyWith(color: TR.muted)),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: t.fare),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) =>
                        Text(TR.le(v, decimals: true), style: TS.h1.copyWith(color: TR.navy)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Divider(color: TR.line, height: 1),
                const SizedBox(height: 12),
                _line('Ride', '${t.rideName} · ${t.distanceKm.toStringAsFixed(1)} km'),
                _line('Driver', '${t.driverName} · ${t.driverPlate}'),
                _line('Payment', t.paymentLabel),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
            const SizedBox(height: 16),
            if (transfer && !acc.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: TR.brandGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(acc.provider == 'Bank' ? PhosphorIconsFill.bank : PhosphorIconsFill.deviceMobile,
                        color: TR.greenBright),
                    const SizedBox(width: 8),
                    Text('Send to ${acc.title}', style: TS.label.copyWith(color: Colors.white)),
                  ]),
                  const SizedBox(height: 12),
                  _copyRow('Account name', acc.accountName.isEmpty ? t.driverName : acc.accountName),
                  _copyRow(acc.provider == 'Bank' ? 'Account number' : 'Mobile number', acc.accountNumber,
                      copy: true),
                  _copyRow('Amount', TR.le(t.fare), copy: true, copyText: t.fare.round().toString()),
                ]),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15)
            else if (transfer)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: TR.amberTint, borderRadius: BorderRadius.circular(14)),
                child: Text('Ask ${t.driverName} for their account details, or pay in cash.',
                    style: TS.small.copyWith(color: TR.ink)),
              ),
            const SizedBox(height: 16),
            TRButton(
              label: transfer ? 'I’ve sent ${TR.le(t.fare)}' : 'I’ve paid ${TR.le(t.fare)} in cash',
              icon: transfer ? PhosphorIconsFill.paperPlaneTilt : PhosphorIconsFill.money,
              loading: _busy,
              onPressed: () => _markPaid(t),
            ),
            const SizedBox(height: 10),
            TRButton(
              label: 'Message ${t.driverName.split(' ').first}',
              kind: BtnKind.outline,
              icon: PhosphorIconsFill.chatCircleDots,
              onPressed: () => _chat(t),
            ),
            const SizedBox(height: 10),
            Text('TrustRide never handles your money — you pay your driver directly.',
                textAlign: TextAlign.center, style: TS.small.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(String label, String value, {bool copy = false, String? copyText}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 116,
            child: Text(label, style: TS.small.copyWith(color: const Color(0xFFD6E2F0))),
          ),
          Expanded(
            child: SelectableText(value, style: TS.label.copyWith(color: Colors.white, fontSize: 16)),
          ),
          if (copy)
            IconButton(
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyText ?? value));
                showToast(context, '$label copied');
              },
              icon: const Icon(PhosphorIconsBold.copy, color: Colors.white, size: 18),
            ),
        ]),
      );

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
