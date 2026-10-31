import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// Drivers are paid directly by riders (cash or transfer), so earnings come
/// straight from completed trips. The driver owes TrustRide its commission;
/// admins record commission payments.
class DriverEarningsTab extends StatefulWidget {
  const DriverEarningsTab({super.key});
  @override
  State<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends State<DriverEarningsTab> {
  String? _uid;
  Stream<List<Trip>>? _trips;
  int? _selected;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.driver;
    if (d == null) return const Loading();
    if (_uid != d.uid) {
      _uid = d.uid;
      _trips = Db.driverTrips(d.uid);
    }
    final c = s.config.commission;

    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Trip>>(
          stream: _trips,
          builder: (context, tSnap) {
            if (!tSnap.hasData) return const Loading();
            final done = tSnap.data!.where((t) => t.status == TripStatus.completed).toList();
            final unpaid = done.where((t) => !t.paid).toList();

            double gross = 0, tips = 0;
            for (final t in done) {
              gross += t.fare;
              tips += t.tip;
            }
            final commission = gross * c;
            final owed = commission - d.commissionPaid;
            final net = gross - commission + tips;

            final today = DateTime.now();
            final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
            final week = List<double>.filled(7, 0);
            final weekTrips = List<int>.filled(7, 0);
            for (final t in done) {
              final at = t.completedAt ?? t.createdAt;
              if (at == null || at.isBefore(start)) continue;
              final i = DateTime(at.year, at.month, at.day).difference(start).inDays;
              if (i >= 0 && i < 7) {
                week[i] += t.fare * (1 - c) + t.tip;
                weekTrips[i] += 1;
              }
            }
            final weekTotal = week.fold<double>(0, (a, b) => a + b);
            final maxV = week.fold<double>(1, (a, b) => b > a ? b : a);
            final sel = _selected ?? 6;
            String dayName(int i) => _dayNames[start.add(Duration(days: i)).weekday - 1];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                const ScreenTitle('Earnings'),
                const SizedBox(height: 16),
                TRCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Last 7 days · after commission', style: TS.small),
                        const Spacer(),
                        Pill('${weekTrips.fold<int>(0, (a, b) => a + b)} trips'),
                      ]),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: weekTotal),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) =>
                            Text(TR.le(v, decimals: true), style: TS.h1.copyWith(color: TR.navy, fontSize: 32)),
                      ),
                      Text('${dayName(sel)}: ${TR.le(week[sel], decimals: true)} · ${weekTrips[sel]} trips',
                          style: TS.label.copyWith(color: TR.green, fontSize: 13)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 150,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Pressable(
                                  onTap: () => setState(() => _selected = i),
                                  semanticLabel: '${dayName(i)} ${TR.le(week[i])}',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: week[i] / maxV),
                                          duration: Duration(milliseconds: 600 + i * 80),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, v, __) => Container(
                                            height: (110 * v).clamp(4.0, 120.0).toDouble(),
                                            decoration: BoxDecoration(
                                              gradient: i == sel
                                                  ? const LinearGradient(
                                                      colors: [TR.greenBright, TR.green],
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter)
                                                  : null,
                                              color: i == sel ? null : const Color(0xFFC9D6E3),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(dayName(i).substring(0, 1),
                                            style: TS.small.copyWith(
                                                fontSize: 12,
                                                fontWeight: i == sel ? FontWeight.w800 : FontWeight.w500)),
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
                ).animate().fadeIn().slideY(begin: 0.08),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: owed > 0.5
                        ? const LinearGradient(colors: [Color(0xFF8A5A00), TR.gold])
                        : TR.brandGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Icon(owed > 0.5 ? PhosphorIconsFill.receipt : PhosphorIconsFill.sealCheck,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(owed > 0.5 ? 'Commission due to TrustRide' : 'Commission all paid',
                              style: TS.small.copyWith(color: Colors.white, fontSize: 12)),
                          Text(TR.le(owed > 0 ? owed : 0, decimals: true),
                              style: TS.h2.copyWith(color: Colors.white)),
                          Text(
                              owed > 0.5
                                  ? 'Pay at the TrustRide office or to our account. Paid so far: ${TR.le(d.commissionPaid)}'
                                  : 'Thank you! Paid so far: ${TR.le(d.commissionPaid)}',
                              style: TS.small.copyWith(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
                if (s.config.supportPhone.isNotEmpty && owed > 0.5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TRButton(
                      label: 'Call TrustRide to pay',
                      kind: BtnKind.outline,
                      height: 46,
                      icon: PhosphorIconsFill.phoneCall,
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: s.config.supportPhone)),
                    ),
                  ),
                const SizedBox(height: 14),
                if (unpaid.isNotEmpty) ...[
                  const Caps('Waiting for payment'),
                  const SizedBox(height: 10),
                  TRCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final t in unpaid)
                        ListTile(
                          leading: Avatar(initialsOf(t.riderName), photo: t.riderPhoto, size: 40),
                          title: Text('${t.riderName.split(' ').first} · ${TR.le(t.fare)}',
                              style: TS.label.copyWith(fontSize: 14)),
                          subtitle: Text('${t.paymentLabel} · ${dateLabel(t.completedAt)}', style: TS.small),
                          trailing: TextButton(
                            onPressed: () => Db.markPaid(t.id),
                            child: Text('Received', style: TS.label.copyWith(color: TR.green, fontSize: 13)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
                TRCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    _row('All-time fares (${done.length} trips)', TR.le(gross, decimals: true)),
                    _row('Tips', TR.le(tips, decimals: true)),
                    _row('TrustRide commission (${(c * 100).round()}%)', '−${TR.le(commission, decimals: true)}'),
                    const Divider(color: TR.line),
                    _row('Your earnings', TR.le(net, decimals: true), bold: true),
                  ]),
                ).animate().fadeIn(delay: 220.ms),
                const SizedBox(height: 14),
                TRCard(
                  child: Row(children: [
                    IconBubble(d.account.provider == 'Bank' ? PhosphorIconsFill.bank : PhosphorIconsFill.deviceMobile,
                        color: TR.green, bg: TR.greenTint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Riders transfer to', style: TS.small.copyWith(fontSize: 12)),
                        Text(d.account.isEmpty ? 'No account set' : '${d.account.title} · ${d.account.accountNumber}',
                            style: TS.label.copyWith(fontSize: 14)),
                      ]),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(a, style: bold ? TS.label : TS.small.copyWith(fontSize: 14))),
          Text(b, style: TS.label.copyWith(color: bold ? const Color(0xFF1F6B2E) : TR.ink)),
        ]),
      );
}
