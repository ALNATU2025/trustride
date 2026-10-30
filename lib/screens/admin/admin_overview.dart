import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';
import 'admin_trips.dart';

class AdminOverview extends StatefulWidget {
  const AdminOverview({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;
  @override
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> {
  late final Stream<List<Trip>> _trips = Db.recentTrips(limit: 500);
  late final Stream<List<DriverProfile>> _online = Db.onlineDrivers();
  late final Stream<List<SosAlert>> _sos = Db.openSos();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return StreamBuilder<List<Trip>>(
      stream: _trips,
      builder: (context, tSnap) => StreamBuilder<List<DriverProfile>>(
        stream: _online,
        builder: (context, dSnap) => StreamBuilder<List<SosAlert>>(
          stream: _sos,
          builder: (context, sSnap) {
            if (tSnap.hasError) {
              return EmptyState(
                  icon: PhosphorIconsFill.warning,
                  title: 'Couldn’t load data',
                  body: errorText(tSnap.error!));
            }
            if (!tSnap.hasData) return const Loading();
            final all = tSnap.data!;
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final today = all
                .where((t) => t.createdAt != null && !t.createdAt!.isBefore(todayStart))
                .toList();
            final done = today.where((t) => t.status == TripStatus.completed).toList();
            final cancelled = today.where((t) => t.status == TripStatus.cancelled).length;
            final live = all.where((t) => t.isActive).toList();
            final gross = done.fold<double>(0, (a, t) => a + t.fare);
            final rated = done.where((t) => t.rating != null).toList();
            final avgRating = rated.isEmpty
                ? null
                : rated.fold<int>(0, (a, t) => a + t.rating!) / rated.length;
            final online = dSnap.data?.length ?? 0;
            final sos = sSnap.data ?? const <SosAlert>[];

            final hours = List<int>.filled(24, 0);
            for (final t in today) {
              hours[t.createdAt!.hour]++;
            }
            final maxH = hours.fold<int>(1, (a, b) => b > a ? b : a);
            final mix = <String, int>{};
            for (final t in done) {
              mix[t.rideName] = (mix[t.rideName] ?? 0) + 1;
            }

            final kpis = [
              (PhosphorIconsFill.path, 'Trips today', '${today.length}',
                  '${done.length} completed · $cancelled cancelled'),
              (PhosphorIconsFill.coins, 'Bookings today', TR.le(gross),
                  'Commission ${TR.le(gross * s.config.commission)}'),
              (PhosphorIconsFill.steeringWheel, 'Drivers online', '$online',
                  '${live.length} trips in progress'),
              (PhosphorIconsFill.star, 'Avg rating today',
                  avgRating == null ? '—' : avgRating.toStringAsFixed(2),
                  '${rated.length} ratings'),
            ];

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AdminHeader(
                  title: 'Overview',
                  subtitle: 'Live · ${dateLabel(now)}',
                ),
                const SizedBox(height: 20),
                if (sos.isNotEmpty) ...[
                  for (final a in sos) _sosCard(a),
                  const SizedBox(height: 6),
                ],
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
                  final w = (c.maxWidth - (cols - 1) * 14) / cols - 0.5;
                  return Wrap(spacing: 14, runSpacing: 14, children: [
                    for (var i = 0; i < kpis.length; i++)
                      SizedBox(
                        width: w,
                        child: AdminCard(
                          padding: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(kpis[i].$2,
                                      style: TS.small.copyWith(fontWeight: FontWeight.w600)),
                                ),
                                IconBubble(kpis[i].$1, size: 32, color: TR.green, bg: TR.greenTint),
                              ]),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(kpis[i].$3, style: TS.h2.copyWith(color: TR.navy)),
                              ),
                              const SizedBox(height: 4),
                              Text(kpis[i].$4, style: TS.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.15),
                  ]);
                }),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 820;
                  final chart = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Requests by hour · today', style: TS.h3),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 190,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var h = 5; h < 24; h++)
                                Expanded(
                                  child: Tooltip(
                                    message: '$h:00 · ${hours[h]} requests',
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: hours[h] / maxH),
                                            duration: const Duration(milliseconds: 700),
                                            curve: Curves.easeOutCubic,
                                            builder: (_, v, __) => Container(
                                              height: (160 * v).clamp(2.0, 160.0).toDouble(),
                                              decoration: BoxDecoration(
                                                color: h == now.hour ? TR.green : const Color(0xFF9FB7D4),
                                                borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(5)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text('$h', style: TS.small.copyWith(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  final side = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ride mix · completed today', style: TS.h3),
                        const SizedBox(height: 12),
                        if (mix.isEmpty)
                          Text('No completed trips yet today.', style: TS.small)
                        else
                          for (final e in mix.entries) ...[
                            Row(children: [
                              Expanded(child: Text(e.key, style: TS.label.copyWith(fontSize: 14))),
                              Text('${e.value} · ${(e.value / done.length * 100).round()}%',
                                  style: TS.small),
                            ]),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: e.value / done.length,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFEEF1F5),
                                color: TR.navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  );
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: chart),
                            const SizedBox(width: 14),
                            Expanded(child: side),
                          ],
                        )
                      : Column(children: [chart, const SizedBox(height: 14), side]);
                }),
                const SizedBox(height: 16),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text('Trips in progress', style: TS.h3)),
                        TextButton(
                          onPressed: () => widget.onOpen(2),
                          child: Text('All trips',
                              style: TS.label.copyWith(color: TR.navy, fontSize: 14)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      if (live.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('No trips in progress right now.', style: TS.small),
                        )
                      else
                        TripTable(trips: live.take(20).toList()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sosCard(SosAlert a) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AdminCard(
          color: TR.dangerTint,
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(PhosphorIconsFill.siren, color: TR.danger, size: 28)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(end: 1.15, duration: 600.ms),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOS from ${a.name}',
                      style: TS.label.copyWith(color: const Color(0xFFA12222))),
                  Text(
                      '${a.phone} · ${timeAgo(a.createdAt)}'
                      '${a.tripId.isNotEmpty ? ' · trip ${a.tripId}' : ''}',
                      style: TS.small.copyWith(fontSize: 12)),
                ],
              ),
              TRButton(
                label: 'Call',
                kind: BtnKind.outline,
                expand: false,
                height: 40,
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: a.phone)),
              ),
              if (a.location != null)
                TRButton(
                  label: 'Map',
                  kind: BtnKind.outline,
                  expand: false,
                  height: 40,
                  onPressed: () => launchUrl(Uri.parse(
                      'https://www.openstreetmap.org/?mlat=${a.location!.latitude}&mlon=${a.location!.longitude}#map=17/${a.location!.latitude}/${a.location!.longitude}')),
                ),
              TRButton(
                label: 'Resolve',
                kind: BtnKind.danger,
                expand: false,
                height: 40,
                onPressed: () async {
                  await Db.resolveSos(a.id);
                  if (mounted) showToast(context, 'Alert resolved');
                },
              ),
            ],
          ),
        ),
      );
}
