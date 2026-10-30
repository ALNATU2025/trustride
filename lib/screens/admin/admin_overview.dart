import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';
import 'admin_trips.dart';

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;

  static const _hours = [8, 22, 64, 92, 70, 48, 44, 52, 58, 50, 46, 60, 84, 100, 78, 52, 34, 20];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final kpis = [
      (PhosphorIconsFill.path, 'Trips today', '1,284', '+8.2% vs last Friday', true),
      (PhosphorIconsFill.coins, 'Gross bookings', 'Le 108,540', '+5.1% vs last Friday', true),
      (PhosphorIconsFill.steeringWheel, 'Drivers online', '312', 'of 1,046 approved', null),
      (PhosphorIconsFill.timer, 'Avg pickup time', '6.4 min', '+0.6 min (rain)', false),
      (PhosphorIconsFill.star, 'Avg rating', '4.78', 'last 7 days', null),
    ];
    final mix = [
      ('TrustRide Car', 0.46, TR.navy),
      ('Keke', 0.27, TR.green),
      ('Okada', 0.19, const Color(0xFF5B8FCB)),
      ('Comfort AC / XL', 0.08, const Color(0xFF8FBF6A)),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHeader(
          title: 'Overview',
          subtitle: 'Live · Freetown & Western Area',
          actions: [
            SizedBox(
              width: 240,
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Trip ID, phone, plate',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                      size: 18),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TR.border)),
                ),
              ),
            ),
            TRButton(
              label: 'Export',
              icon: PhosphorIconsBold.downloadSimple,
              expand: false,
              height: 44,
              onPressed: () => showToast(context, 'Report exported (CSV)'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100
              ? 5
              : c.maxWidth > 700
                  ? 3
                  : 2;
          final w = (c.maxWidth - (cols - 1) * 14) / cols - 0.5;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
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
                          IconBubble(kpis[i].$1,
                              size: 32, color: TR.green, bg: TR.greenTint),
                        ]),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(kpis[i].$3,
                              style: TS.h2.copyWith(color: TR.navy)),
                        ),
                        const SizedBox(height: 4),
                        Text(kpis[i].$4,
                            style: TS.small.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kpis[i].$5 == null
                                    ? TR.muted
                                    : kpis[i].$5!
                                        ? const Color(0xFF1F6B2E)
                                        : const Color(0xFFA12222))),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.15),
            ],
          );
        }),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 820;
          final chart = AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('Trips by hour · today', style: TS.h3)),
                  Text('Peaks 8–9 AM, 5–6 PM', style: TS.small.copyWith(fontSize: 12)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _hours.length; i++)
                        Expanded(
                          child: Tooltip(
                            message: '${6 + i}:00 · ${(_hours[i] * 1.3).round()} trips',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: _hours[i] / 100),
                                    duration: Duration(milliseconds: 500 + i * 40),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => Container(
                                      height: 170 * v,
                                      decoration: BoxDecoration(
                                        color: _hours[i] >= 84
                                            ? TR.green
                                            : const Color(0xFF9FB7D4),
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(5)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${6 + i}',
                                      style: TS.small.copyWith(fontSize: 10)),
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
          final side = Column(children: [
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride mix', style: TS.h3),
                  const SizedBox(height: 12),
                  for (final m in mix) ...[
                    Row(children: [
                      Expanded(child: Text(m.$1, style: TS.label.copyWith(fontSize: 14))),
                      Text('${(m.$2 * 100).round()}%', style: TS.small),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: m.$2),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEEF1F5),
                          color: m.$3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: s.sosAlerts > 0
                  ? AdminCard(
                      key: const ValueKey('sos'),
                      color: TR.dangerTint,
                      child: Row(children: [
                        const Icon(PhosphorIconsFill.siren,
                                color: TR.danger, size: 28)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(end: 1.15, duration: 600.ms),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1 active SOS alert',
                                  style: TS.label.copyWith(color: const Color(0xFFA12222))),
                              Text('TR-20931 · Kissy Road · 3 min ago',
                                  style: TS.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        TRButton(
                          label: 'Resolve',
                          kind: BtnKind.danger,
                          expand: false,
                          height: 40,
                          onPressed: () {
                            s.resolveSos();
                            showToast(context, 'Incident TR-20931 resolved');
                          },
                        ),
                      ]),
                    )
                  : AdminCard(
                      key: const ValueKey('ok'),
                      color: TR.greenTint,
                      child: Row(children: [
                        const Icon(PhosphorIconsFill.shieldCheck,
                            color: TR.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('No open safety incidents',
                                style: TS.label.copyWith(color: const Color(0xFF1F6B2E)))),
                      ]),
                    ),
            ),
          ]);
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
                Expanded(child: Text('Live trips', style: TS.h3)),
                TextButton(
                  onPressed: () => onOpen(2),
                  child: Text('View all',
                      style: TS.label.copyWith(color: TR.navy, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 8),
              TripTable(trips: Mock.adminTrips.take(5).toList()),
            ],
          ),
        ),
      ],
    );
  }
}
