import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _paying = false;

  Future<void> _pay() async {
    final s = AppScope.read(context);
    setState(() => _paying = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final ok = s.pay();
    setState(() => _paying = false);
    if (!ok) {
      showToast(context, 'Wallet balance too low — pick another method',
          icon: PhosphorIconsFill.warning);
      return;
    }
    showToast(context,
        s.paymentId == 'cash' ? 'Please pay your driver in cash' : 'Payment successful');
    Navigator.of(context).pushReplacementNamed(R.rate);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.ride;
    final km = s.destination.km;
    final distance = r.perKm * km * 0.82;
    final time = s.fare - r.base - distance;
    final rows = [
      ('Base fare', r.base),
      ('Distance · ${km.toStringAsFixed(1)} km', distance),
      ('Time · ${s.tripMinutes} min', time < 0 ? 0.0 : time),
      ('Booking fee', 0.0),
    ];
    final now = TimeOfDay.now().format(context);

    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [TR.greenBright, TR.green]),
                  boxShadow: [
                    BoxShadow(color: TR.green.fade(0.35), blurRadius: 30),
                  ],
                ),
                child: const Icon(PhosphorIconsBold.check,
                    color: Colors.white, size: 38),
              ).animate().scale(
                  duration: 700.ms, curve: Curves.elasticOut),
            ),
            const SizedBox(height: 14),
            Center(child: Text('You’ve arrived', style: TS.h2)),
            Center(
                child: Text('${s.destination.name} · $now', style: TS.small)),
            const SizedBox(height: 22),
            TRCard(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total', style: TS.label.copyWith(color: TR.muted)),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: s.fare),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(TR.le(v, decimals: true),
                          style: TS.h1.copyWith(color: TR.navy)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: TR.line, height: 1),
                const SizedBox(height: 12),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Text(row.$1, style: TS.small.copyWith(fontSize: 14)),
                      const Spacer(),
                      Text(TR.le(row.$2, decimals: true),
                          style: TS.label.copyWith(fontSize: 14)),
                    ]),
                  ),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
            const SizedBox(height: 20),
            const Caps('Pay with'),
            const SizedBox(height: 10),
            for (var i = 0; i < Mock.payMethods.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectTile(
                  selected: s.paymentId == Mock.payMethods[i].id,
                  onTap: () => s.setPayment(Mock.payMethods[i].id),
                  child: Row(children: [
                    PayDot(Mock.payMethods[i].color, Mock.payMethods[i].icon,
                        size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(Mock.payMethods[i].name, style: TS.label)),
                    Text(
                        Mock.payMethods[i].id == 'wallet'
                            ? TR.le(s.wallet, decimals: true)
                            : Mock.payMethods[i].detail,
                        style: TS.small),
                  ]),
                ),
              )
                  .animate()
                  .fadeIn(delay: (300 + i * 60).ms)
                  .slideX(begin: 0.08),
            const SizedBox(height: 16),
            TRButton(
              label: s.paymentId == 'cash'
                  ? 'Confirm cash payment'
                  : 'Pay ${TR.le(s.fare, decimals: true)}',
              loading: _paying,
              icon: PhosphorIconsFill.lockSimple,
              onPressed: _pay,
            ),
          ],
        ),
      ),
    );
  }
}
