import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  Stream<List<Trip>>? _trips;
  String? _uid;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final uid = s.authUser?.uid;
    if (uid != null && uid != _uid) {
      _uid = uid;
      _trips = Db.riderTrips(uid);
    }
    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Trip>>(
          stream: _trips,
          builder: (context, snap) {
            final trips = snap.data ?? const <Trip>[];
            final done = trips.where((t) => t.status == TripStatus.completed);
            final total = done.fold<double>(0, (a, t) => a + t.fare);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text('My trips', style: TS.h2),
                const SizedBox(height: 4),
                Text('${done.length} completed · ${TR.le(total)} spent',
                    style: TS.small),
                const SizedBox(height: 16),
                if (snap.hasError)
                  const EmptyState(
                      icon: PhosphorIconsFill.warning,
                      title: 'Couldn’t load trips',
                      body: 'Check your connection and try again.')
                else if (!snap.hasData)
                  const Loading()
                else if (trips.isEmpty)
                  const EmptyState(
                    icon: PhosphorIconsFill.carProfile,
                    title: 'No trips yet',
                    body: 'Your rides will appear here after you book.',
                  )
                else
                  for (var i = 0; i < trips.length; i++)
                    _TripCard(trip: trips[i])
                        .animate()
                        .fadeIn(delay: (40 * i.clamp(0, 10)).ms)
                        .slideY(begin: 0.15, curve: Curves.easeOutCubic),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  (String, PillKind) get _status => switch (trip.status) {
        TripStatus.completed => ('Completed', PillKind.success),
        TripStatus.cancelled => ('Cancelled', PillKind.danger),
        _ => ('In progress', PillKind.info),
      };

  @override
  Widget build(BuildContext context) {
    final st = _status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        scale: 0.98,
        onTap: () {
          if (trip.isActive) {
            AppScope.read(context).setCurrentTrip(trip.id);
            Navigator.of(context).pushNamed(R.ride);
          } else {
            _showReceipt(context);
          }
        },
        child: TRCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Text(dateLabel(trip.createdAt),
                  style: TS.small.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Pill(st.$1, kind: st.$2),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const RouteRail(height: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.pickup.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TS.label.copyWith(fontSize: 14)),
                    const SizedBox(height: 10),
                    Text(trip.dropoff.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TS.label.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(trip.status == TripStatus.cancelled ? 'Le 0' : TR.le(trip.fare),
                      style: TS.h3.copyWith(fontSize: 16)),
                  Text(trip.rideName, style: TS.small.copyWith(fontSize: 12)),
                  if (trip.rating != null)
                    Row(children: [
                      const Icon(PhosphorIconsFill.star, color: TR.gold, size: 12),
                      Text(' ${trip.rating}', style: TS.small.copyWith(fontSize: 12)),
                    ]),
                ],
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context) {
    final support = AppScope.read(context).config.supportPhone;
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
              const IconBubble(PhosphorIconsFill.receipt, color: TR.green, bg: TR.greenTint),
              const SizedBox(width: 12),
              Expanded(child: Text('Receipt', style: TS.h3)),
              Text(trip.status == TripStatus.cancelled ? 'Le 0' : TR.le(trip.fare, decimals: true),
                  style: TS.h3.copyWith(color: TR.navy)),
            ]),
            const SizedBox(height: 14),
            Text('${trip.pickup.label} → ${trip.dropoff.label}', style: TS.label),
            const SizedBox(height: 4),
            Text(
                '${dateLabel(trip.createdAt)} · ${trip.rideName} · ${trip.distanceKm.toStringAsFixed(1)} km',
                style: TS.small),
            if (trip.hasDriver)
              Text('Driver: ${trip.driverName} · ${trip.driverPlate}', style: TS.small),
            Text('Paid by ${trip.payment == 'wallet' ? 'TrustRide Wallet' : 'cash'}'
                '${trip.tip > 0 ? ' · tip ${TR.le(trip.tip)}' : ''}',
                style: TS.small),
            Text('Trip ID: ${trip.id}', style: TS.small.copyWith(fontSize: 11)),
            const SizedBox(height: 18),
            TRButton(
              label: support.isEmpty ? 'Support coming soon' : 'Call support',
              kind: BtnKind.outline,
              height: 50,
              icon: PhosphorIconsFill.headset,
              onPressed: support.isEmpty
                  ? null
                  : () => launchUrl(Uri(scheme: 'tel', path: support)),
            ),
          ],
        ),
      ),
    );
  }
}
