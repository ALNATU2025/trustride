import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

(String, PillKind) tripStatusPill(Trip t) {
  if (t.sos && t.isActive) return ('SOS', PillKind.danger);
  return switch (t.status) {
    TripStatus.completed => (t.paid ? 'Completed' : 'Unpaid', t.paid ? PillKind.success : PillKind.warning),
    TripStatus.cancelled => ('Cancelled', PillKind.neutral),
    TripStatus.requested => ('Searching', PillKind.warning),
    TripStatus.inProgress => ('On trip', PillKind.info),
    _ => ('Pickup', PillKind.info),
  };
}

/// Horizontally scrollable trips table.
class TripTable extends StatelessWidget {
  const TripTable({super.key, required this.trips});
  final List<Trip> trips;

  static const _cols = [
    ('Date', 120.0),
    ('Rider', 140.0),
    ('Driver', 140.0),
    ('Route', 260.0),
    ('Type', 110.0),
    ('Payment', 90.0),
    ('Fare', 80.0),
    ('Status', 110.0),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(int i, Widget child) => SizedBox(width: _cols[i].$2, child: child);
    final small = TS.small.copyWith(fontSize: 13);
    final strong = TS.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              for (var i = 0; i < _cols.length; i++)
                cell(i, Text(_cols[i].$1.toUpperCase(), style: TS.caps.copyWith(fontSize: 11))),
            ]),
          ),
          for (var r = 0; r < trips.length; r++)
            Builder(builder: (context) {
              final t = trips[r];
              final st = tripStatusPill(t);
              return InkWell(
                onTap: () => showTripDetails(context, t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFEEF1F5)))),
                  child: Row(children: [
                    cell(0, Text(dateLabel(t.createdAt), style: small)),
                    cell(1, Text(t.riderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: strong)),
                    cell(2, Text(t.hasDriver ? t.driverName : '—',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: strong)),
                    cell(3, Text('${t.pickup.label} → ${t.dropoff.label}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: small)),
                    cell(4, Text(t.rideName, style: strong)),
                    cell(5, Text(t.payment == 'transfer' ? 'Transfer' : 'Cash', style: small)),
                    cell(6, Text(TR.le(t.fare), style: strong)),
                    cell(7, Align(
                        alignment: Alignment.centerLeft,
                        child: Pill(st.$1, kind: st.$2))),
                  ]),
                ),
              ).animate().fadeIn(delay: (20 * r.clamp(0, 15)).ms);
            }),
        ],
      ),
    );
  }
}

void showTripDetails(BuildContext context, Trip t) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Trip ${t.id}', style: TS.h3),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in [
              ('Status', tripStatusPill(t).$1),
              ('Requested', dateLabel(t.createdAt)),
              ('Completed', t.completedAt == null ? '—' : dateLabel(t.completedAt)),
              ('Rider', '${t.riderName} · ${t.riderPhone}'),
              ('Driver', t.hasDriver ? '${t.driverName} · ${t.driverPhone} · ${t.driverPlate}' : '—'),
              ('From', '${t.pickup.label}, ${t.pickup.address}'),
              ('To', '${t.dropoff.label}, ${t.dropoff.address}'),
              ('Ride', '${t.rideName} · ${t.distanceKm.toStringAsFixed(1)} km · ${t.durationMin.round()} min'),
              ('Fare', '${TR.le(t.fare, decimals: true)} · ${t.paymentLabel} · ${t.paid ? 'paid' : 'not paid'}'),
              if (t.forSomeoneElse) ('Passenger', '${t.passengerName} · ${t.passengerPhone}'),
              if (t.note.isNotEmpty) ('Note', t.note),
              ('Suggested', TR.le(t.suggestedFare)),
              ('Tip / rating', '${TR.le(t.tip)} · ${t.rating == null ? 'not rated' : '${t.rating}★'}'),
              if (t.cancelledBy.isNotEmpty) ('Cancelled by', t.cancelledBy),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 100, child: Text(row.$1, style: TS.small)),
                  Expanded(child: Text(row.$2, style: TS.label.copyWith(fontSize: 14))),
                ]),
              ),
          ],
        ),
      ),
      actions: [
        if (t.isActive)
          TextButton(
            onPressed: () async {
              await Db.cancelTrip(t.id, 'admin');
              if (c.mounted) Navigator.pop(c);
            },
            child: Text('Cancel trip', style: TS.label.copyWith(color: TR.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text('Close', style: TS.label.copyWith(color: TR.navy)),
        ),
      ],
    ),
  );
}

class AdminTrips extends StatefulWidget {
  const AdminTrips({super.key});
  @override
  State<AdminTrips> createState() => _AdminTripsState();
}

class _AdminTripsState extends State<AdminTrips> {
  late final Stream<List<Trip>> _trips = Db.recentTrips(limit: 500);
  String _filter = 'All';
  String _q = '';
  static const _filters = ['All', 'Active', 'Completed', 'Unpaid', 'Cancelled', 'Cash', 'Transfer', 'SOS'];

  bool _match(Trip t) {
    final ok = switch (_filter) {
      'Active' => t.isActive,
      'Completed' => t.status == TripStatus.completed,
      'Unpaid' => t.status == TripStatus.completed && !t.paid,
      'Cancelled' => t.status == TripStatus.cancelled,
      'Cash' => t.payment == 'cash',
      'Transfer' => t.payment == 'transfer',
      'SOS' => t.sos,
      _ => true,
    };
    if (!ok) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return t.id.toLowerCase().contains(q) ||
        t.riderName.toLowerCase().contains(q) ||
        t.riderPhone.contains(q) ||
        t.driverName.toLowerCase().contains(q) ||
        t.driverPhone.contains(q) ||
        t.driverPlate.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).config.commission;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AdminHeader(title: 'Trips', subtitle: 'Latest 500 trips · live'),
        const SizedBox(height: 20),
        StreamBuilder<List<Trip>>(
          stream: _trips,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(
                  icon: PhosphorIconsFill.warning,
                  title: 'Couldn’t load trips',
                  body: errorText(snap.error!));
            }
            if (!snap.hasData) return const Loading();
            final all = snap.data!;
            final rows = all.where(_match).toList();
            final done = all.where((t) => t.status == TripStatus.completed);
            final gross = done.fold<double>(0, (a, t) => a + t.fare);
            return AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 18, runSpacing: 8, children: [
                    Text('Completed: ${done.length}', style: TS.label),
                    Text('Bookings: ${TR.le(gross)}', style: TS.label),
                    Text('Commission: ${TR.le(gross * c)}', style: TS.label),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 320,
                    height: 44,
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search name, phone, plate or trip ID',
                        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: TR.border)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in _filters)
                        Pressable(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _filter == f ? TR.navy : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _filter == f ? TR.navy : TR.border),
                            ),
                            child: Text(f,
                                style: TS.label.copyWith(
                                    fontSize: 13, color: _filter == f ? Colors.white : TR.ink)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: Text('No trips match.', style: TS.small)),
                    )
                  else
                    TripTable(trips: rows.take(200).toList()),
                  const SizedBox(height: 8),
                  Text('Showing ${rows.length > 200 ? 200 : rows.length} of ${rows.length} · tap a row for details',
                      style: TS.small.copyWith(fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
