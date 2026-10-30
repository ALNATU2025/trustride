import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  bool _past = true;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final total = s.trips
        .where((t) => t.status == TripStatus.completed)
        .fold<double>(0, (a, t) => a + t.fare);
    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('My trips', style: TS.h2),
            const SizedBox(height: 4),
            Text('${s.trips.length} trips · ${TR.le(total)} spent', style: TS.small),
            const SizedBox(height: 16),
            Row(children: [
              _seg('Past', _past, () => setState(() => _past = true)),
              const SizedBox(width: 8),
              _seg('Scheduled', !_past, () => setState(() => _past = false)),
            ]),
            const SizedBox(height: 16),
            if (!_past)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  const IconBubble(PhosphorIconsFill.calendarBlank,
                      size: 72, color: TR.green, bg: TR.greenTint),
                  const SizedBox(height: 12),
                  Text('No scheduled rides', style: TS.h3),
                  const SizedBox(height: 4),
                  Text('Book ahead for early flights at Lungi.',
                      style: TS.small),
                ]).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              )
            else
              for (var i = 0; i < s.trips.length; i++)
                _TripCard(trip: s.trips[i])
                    .animate()
                    .fadeIn(delay: (50 * i).ms)
                    .slideY(begin: 0.15, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback tap) => Pressable(
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: on ? TR.navy : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: on ? TR.navy : TR.border),
          ),
          child: Text(label,
              style: TS.label.copyWith(
                  fontSize: 13, color: on ? Colors.white : TR.ink)),
        ),
      );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final done = trip.status == TripStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        scale: 0.98,
        onTap: () => _showReceipt(context),
        child: TRCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Text(trip.when, style: TS.small.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Pill(done ? 'Completed' : 'Cancelled',
                  kind: done ? PillKind.success : PillKind.danger),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const RouteRail(height: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.from, style: TS.label.copyWith(fontSize: 14)),
                    const SizedBox(height: 10),
                    Text(trip.to, style: TS.label.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(TR.le(trip.fare), style: TS.h3.copyWith(fontSize: 16)),
                  Text(trip.rideName, style: TS.small.copyWith(fontSize: 12)),
                  if (trip.rating != null)
                    Row(children: [
                      const Icon(PhosphorIconsFill.star,
                          color: TR.gold, size: 12),
                      Text(' ${trip.rating}',
                          style: TS.small.copyWith(fontSize: 12)),
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
              const IconBubble(PhosphorIconsFill.receipt,
                  color: TR.green, bg: TR.greenTint),
              const SizedBox(width: 12),
              Expanded(child: Text('Trip ${trip.id}', style: TS.h3)),
              Text(TR.le(trip.fare), style: TS.h3.copyWith(color: TR.navy)),
            ]),
            const SizedBox(height: 14),
            Text('${trip.from} → ${trip.to}', style: TS.label),
            Text('${trip.when} · ${trip.rideName}', style: TS.small),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: TRButton(
                    label: 'Get help',
                    kind: BtnKind.outline,
                    height: 50,
                    onPressed: () {
                      Navigator.pop(c);
                      showToast(context, 'Support will reply within 1 hour',
                          icon: PhosphorIconsFill.headset);
                    }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TRButton(
                    label: 'Email receipt',
                    height: 50,
                    onPressed: () {
                      Navigator.pop(c);
                      showToast(context, 'Receipt sent');
                    }),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
