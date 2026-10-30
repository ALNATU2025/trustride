import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class DriverEarningsTab extends StatefulWidget {
  const DriverEarningsTab({super.key});
  @override
  State<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends State<DriverEarningsTab> {
  int? _selected;
  bool _cashing = false;

  static const _days = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  Future<void> _cashOut(AppState s) async {
    if (s.driverAvailable <= 0) return;
    setState(() => _cashing = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final amount = s.driverAvailable;
    s.cashOut();
    setState(() => _cashing = false);
    showToast(context,
        '${TR.le(amount, decimals: true)} sent to Orange Money ·· 731',
        icon: PhosphorIconsFill.paperPlaneTilt);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final week = s.driverWeek;
    final gross = week.fold<double>(0, (a, b) => a + b) / 0.85;
    final net = week.fold<double>(0, (a, b) => a + b);
    final maxV = week.reduce((a, b) => a > b ? a : b);
    final sel = _selected ?? week.length - 1;

    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
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
                    Text('This week · 24–30 Oct', style: TS.small),
                    const Spacer(),
                    Pill('${45 + s.driverTripsToday} trips'),
                  ]),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: net),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text(TR.le(v, decimals: true),
                        style: TS.h1.copyWith(color: TR.navy, fontSize: 32)),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${_days[sel]}: ${TR.le(week[sel], decimals: true)}',
                      key: ValueKey(sel),
                      style: TS.label.copyWith(color: TR.green, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < week.length; i++)
                          Expanded(
                            child: Pressable(
                              onTap: () => setState(() => _selected = i),
                              semanticLabel:
                                  '${_days[i]} ${TR.le(week[i])}',
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(
                                          begin: 0, end: week[i] / maxV),
                                      duration: Duration(
                                          milliseconds: 600 + i * 80),
                                      curve: Curves.easeOutBack,
                                      builder: (_, v, __) => AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        height: (110 * v).clamp(4.0, 120.0).toDouble(),
                                        decoration: BoxDecoration(
                                          gradient: i == sel
                                              ? const LinearGradient(
                                                  colors: [
                                                    TR.greenBright,
                                                    TR.green
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter)
                                              : null,
                                          color: i == sel
                                              ? null
                                              : const Color(0xFFC9D6E3),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(_days[i].substring(0, 1),
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
                gradient: TR.brandGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available to cash out',
                          style: TS.small.copyWith(
                              color: const Color(0xFFD6E2F0), fontSize: 12)),
                      Text(TR.le(s.driverAvailable, decimals: true),
                          style: TS.h2.copyWith(color: Colors.white)),
                      Text('To Orange Money ·· 731',
                          style: TS.small.copyWith(
                              color: const Color(0xFFD6E2F0), fontSize: 12)),
                    ],
                  ),
                ),
                TRButton(
                  label: 'Cash out',
                  kind: BtnKind.light,
                  expand: false,
                  height: 46,
                  loading: _cashing,
                  onPressed:
                      s.driverAvailable > 0 ? () => _cashOut(s) : null,
                ),
              ]),
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
            const SizedBox(height: 14),
            TRCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                _row('Trip fares', TR.le(gross, decimals: true)),
                _row('Tips', TR.le(148, decimals: true)),
                _row('TrustRide commission (15%)',
                    '−${TR.le(gross - net, decimals: true)}'),
                const Divider(color: TR.line),
                _row('Net earnings', TR.le(net, decimals: true), bold: true),
              ]),
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: 14),
            TRCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const IconBubble(PhosphorIconsFill.trophy,
                    color: TR.gold, bg: TR.amberTint, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekend quest', style: TS.label),
                      Text('Complete 20 trips Sat–Sun to earn a Le 150 bonus',
                          style: TS.small.copyWith(fontSize: 12)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.6,
                          minHeight: 6,
                          backgroundColor: TR.line,
                          color: TR.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ).animate().fadeIn(delay: 320.ms),
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Text(a,
                style: bold ? TS.label : TS.small.copyWith(fontSize: 14)),
          ),
          Text(b,
              style: TS.label.copyWith(
                  color: bold ? const Color(0xFF1F6B2E) : TR.ink)),
        ]),
      );
}
