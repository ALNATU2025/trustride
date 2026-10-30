import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// Earnings are calculated from completed trips:
///  - cash trips: driver keeps the cash and owes TrustRide its commission;
///  - wallet trips: TrustRide holds the fare and owes the driver their share.
/// Balance = wallet share + wallet tips − cash commission − payouts.
class DriverEarningsTab extends StatefulWidget {
  const DriverEarningsTab({super.key});
  @override
  State<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends State<DriverEarningsTab> {
  String? _uid;
  Stream<List<Trip>>? _trips;
  Stream<List<Payout>>? _payouts;
  int? _selected;
  bool _requesting = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _requestPayout(DriverProfile d, double amount) async {
    setState(() => _requesting = true);
    try {
      await Db.requestPayout(d, amount);
      if (mounted) {
        showToast(context,
            'Cash-out of ${TR.le(amount, decimals: true)} requested to ${d.payoutProvider}',
            icon: PhosphorIconsFill.paperPlaneTilt);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.driver;
    if (d == null) return const Loading();
    if (_uid != d.uid) {
      _uid = d.uid;
      _trips = Db.driverTrips(d.uid);
      _payouts = Db.driverPayouts(d.uid);
    }
    final c = s.config.commission;

    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Trip>>(
          stream: _trips,
          builder: (context, tSnap) => StreamBuilder<List<Payout>>(
            stream: _payouts,
            builder: (context, pSnap) {
              if (!tSnap.hasData) return const Loading();
              final done =
                  tSnap.data!.where((t) => t.status == TripStatus.completed).toList();
              final payouts = pSnap.data ?? const <Payout>[];

              double walletShare = 0, cashCommission = 0, gross = 0, tips = 0;
              for (final t in done) {
                gross += t.fare;
                tips += t.tip;
                if (t.payment == 'wallet') {
                  walletShare += t.fare * (1 - c) + t.tip;
                } else {
                  cashCommission += t.fare * c;
                }
              }
              final paidOut = payouts
                  .where((p) => p.status != 'rejected')
                  .fold<double>(0, (a, p) => a + p.amount);
              final balance = walletShare - cashCommission - paidOut;
              final net = gross * (1 - c) + tips;

              // Last 7 days, oldest first.
              final today = DateTime.now();
              final start = DateTime(today.year, today.month, today.day)
                  .subtract(const Duration(days: 6));
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
              String dayName(int i) =>
                  _dayNames[start.add(Duration(days: i)).weekday - 1];

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text('Earnings', style: TS.h2),
                  const SizedBox(height: 16),
                  TRCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Last 7 days', style: TS.small),
                          const Spacer(),
                          Pill('${weekTrips.fold<int>(0, (a, b) => a + b)} trips'),
                        ]),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: weekTotal),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(TR.le(v, decimals: true),
                              style: TS.h1.copyWith(color: TR.navy, fontSize: 32)),
                        ),
                        Text(
                            '${dayName(sel)}: ${TR.le(week[sel], decimals: true)} · ${weekTrips[sel]} trips',
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
                                                borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(dayName(i).substring(0, 1),
                                              style: TS.small.copyWith(
                                                  fontSize: 12,
                                                  fontWeight: i == sel
                                                      ? FontWeight.w800
                                                      : FontWeight.w500)),
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
                      gradient: balance >= 0
                          ? TR.brandGradient
                          : const LinearGradient(colors: [Color(0xFF8A2A2A), TR.danger]),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(balance >= 0 ? 'Available to cash out' : 'Commission you owe',
                                style: TS.small.copyWith(
                                    color: const Color(0xFFE6EDF5), fontSize: 12)),
                            Text(TR.le(balance.abs(), decimals: true),
                                style: TS.h2.copyWith(color: Colors.white)),
                            Text(
                                balance >= 0
                                    ? 'To ${d.payoutProvider} · ${d.payoutNumber}'
                                    : 'From cash trips. Pay at the TrustRide office.',
                                style: TS.small.copyWith(
                                    color: const Color(0xFFE6EDF5), fontSize: 12)),
                          ],
                        ),
                      ),
                      if (balance > 0)
                        TRButton(
                          label: 'Cash out',
                          kind: BtnKind.light,
                          expand: false,
                          height: 46,
                          loading: _requesting,
                          onPressed: () => _requestPayout(d, balance),
                        ),
                    ]),
                  ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
                  const SizedBox(height: 14),
                  TRCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(children: [
                      _row('All-time fares (${done.length} trips)', TR.le(gross, decimals: true)),
                      _row('Tips', TR.le(tips, decimals: true)),
                      _row('TrustRide commission (${(c * 100).round()}%)',
                          '−${TR.le(gross * c, decimals: true)}'),
                      const Divider(color: TR.line),
                      _row('Your earnings', TR.le(net, decimals: true), bold: true),
                    ]),
                  ).animate().fadeIn(delay: 220.ms),
                  const SizedBox(height: 18),
                  const Caps('Cash-outs'),
                  const SizedBox(height: 10),
                  if (payouts.isEmpty)
                    Text('No cash-outs yet.', style: TS.small)
                  else
                    TRCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final p in payouts)
                          ListTile(
                            leading: const IconBubble(PhosphorIconsFill.paperPlaneTilt, size: 38),
                            title: Text(TR.le(p.amount, decimals: true),
                                style: TS.label.copyWith(fontSize: 14)),
                            subtitle: Text('${p.provider} · ${dateLabel(p.createdAt)}',
                                style: TS.small),
                            trailing: Pill(
                              p.status == 'paid'
                                  ? 'Paid'
                                  : p.status == 'rejected'
                                      ? 'Rejected'
                                      : 'Processing',
                              kind: p.status == 'paid'
                                  ? PillKind.success
                                  : p.status == 'rejected'
                                      ? PillKind.danger
                                      : PillKind.warning,
                            ),
                          ),
                      ]),
                    ),
                ],
              );
            },
          ),
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
