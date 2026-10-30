import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

PillKind statusKind(String s) => switch (s) {
      'Completed' => PillKind.success,
      'En route' => PillKind.info,
      'Pickup' => PillKind.warning,
      'Cancelled' => PillKind.neutral,
      _ => PillKind.danger,
    };

/// Horizontally scrollable trips table used on Overview and Trips pages.
class TripTable extends StatelessWidget {
  const TripTable({super.key, required this.trips});
  final List<AdminTrip> trips;

  static const _cols = [
    ('Trip', 100.0),
    ('Date', 120.0),
    ('Rider', 120.0),
    ('Driver', 140.0),
    ('Route', 230.0),
    ('Type', 110.0),
    ('Payment', 120.0),
    ('Fare', 80.0),
    ('Status', 110.0),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(int i, Widget child) =>
        SizedBox(width: _cols[i].$2, child: child);
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEF1F5)))),
              child: Row(children: [
                cell(0, Text(trips[r].id, style: TS.label.copyWith(fontSize: 13))),
                cell(1, Text(trips[r].date, style: TS.small.copyWith(fontSize: 13))),
                cell(2, Text(trips[r].rider, style: TS.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
                cell(3, Text(trips[r].driver, style: TS.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
                cell(4, Text(trips[r].route, style: TS.small.copyWith(fontSize: 13))),
                cell(5, Text(trips[r].type, style: TS.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
                cell(6, Text(trips[r].pay, style: TS.small.copyWith(fontSize: 13))),
                cell(7, Text(TR.le(trips[r].fare), style: TS.label.copyWith(fontSize: 13))),
                cell(8, Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(trips[r].status, kind: statusKind(trips[r].status)))),
              ]),
            ).animate().fadeIn(delay: (30 * r).ms),
        ],
      ),
    );
  }
}

class AdminTrips extends StatefulWidget {
  const AdminTrips({super.key});
  @override
  State<AdminTrips> createState() => _AdminTripsState();
}

class _AdminTripsState extends State<AdminTrips> {
  String _filter = 'All';
  bool _released = false;
  static const _filters = ['All', 'Completed', 'Cancelled', 'Disputed', 'Cash'];

  @override
  Widget build(BuildContext context) {
    final rows = Mock.adminTrips.where((t) {
      if (_filter == 'All') return true;
      if (_filter == 'Cash') return t.pay == 'Cash';
      return t.status == _filter;
    }).toList();

    final stats = [
      ('Commission earned', 'Le 108,150', '15% on fares', PillKind.success),
      ('Cash to reconcile', '1,906 trips', 'Le 41,300 owed by drivers', PillKind.warning),
      ('Refunds & disputes', '23', '7 need action', PillKind.danger),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHeader(
          title: 'Trips & payouts',
          subtitle: 'Week of 24–30 October 2026',
          actions: [
            TRButton(
              label: 'Download CSV',
              icon: PhosphorIconsBold.downloadSimple,
              expand: false,
              height: 44,
              onPressed: () => showToast(context, 'trips-week-44.csv exported'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 14) / cols - 0.5;
          return Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: TR.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly driver payout batch',
                        style: TS.small.copyWith(color: const Color(0xFFD6E2F0))),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Le 612,840.00',
                          style: TS.h2.copyWith(color: Colors.white)),
                    ),
                    Text('982 drivers · Orange Money 71% · Afrimoney 29%',
                        style: TS.small.copyWith(
                            color: const Color(0xFFD6E2F0), fontSize: 12)),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _released
                          ? const Pill('Released · processing',
                              key: ValueKey('r'),
                              icon: PhosphorIconsFill.checkCircle)
                          : TRButton(
                              key: const ValueKey('b'),
                              label: 'Review & release',
                              kind: BtnKind.light,
                              expand: false,
                              height: 42,
                              onPressed: () => _confirmRelease(context),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            for (final st in stats)
              SizedBox(
                width: w,
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.$1, style: TS.small.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(st.$2, style: TS.h2.copyWith(color: TR.navy)),
                      const SizedBox(height: 6),
                      Pill(st.$3, kind: st.$4),
                    ],
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 16),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('All trips', style: TS.h3),
                  ),
                  for (final f in _filters)
                    Pressable(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _filter == f ? TR.navy : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _filter == f ? TR.navy : TR.border),
                        ),
                        child: Text(f,
                            style: TS.label.copyWith(
                                fontSize: 13,
                                color: _filter == f ? Colors.white : TR.ink)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_filter),
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                              child: Text('No trips match this filter',
                                  style: TS.small)),
                        )
                      : TripTable(trips: rows),
                ),
              ),
              const SizedBox(height: 8),
              Text('Showing ${rows.length} of 9,412 trips',
                  style: TS.small.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRelease(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Release Le 612,840 to 982 drivers?', style: TS.h3),
        content: Text(
            'Payouts go to each driver’s registered mobile money wallet. This cannot be undone.',
            style: TS.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Release', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _released = true);
      if (context.mounted) showToast(context, 'Payout batch released');
    }
  }
}
