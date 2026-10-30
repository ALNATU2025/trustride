import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class WalletTab extends StatelessWidget {
  const WalletTab({super.key});

  void _topUp(BuildContext context) {
    final s = AppScope.read(context);
    var amount = 100;
    var method = 'om';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => BottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              Text('Top up wallet', style: TS.h3),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in [50, 100, 200, 500])
                  SelectTile(
                    selected: amount == a,
                    radius: 14,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    onTap: () => set(() => amount = a),
                    child: Text('Le $a', style: TS.label),
                  ),
              ]),
              const SizedBox(height: 16),
              const Caps('From'),
              const SizedBox(height: 8),
              for (final m in Mock.payMethods.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectTile(
                    selected: method == m.id,
                    onTap: () => set(() => method = m.id),
                    child: Row(children: [
                      PayDot(m.color, m.icon, size: 34),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.name, style: TS.label)),
                      Text(m.detail, style: TS.small),
                    ]),
                  ),
                ),
              const SizedBox(height: 10),
              TRButton(
                label: 'Top up Le $amount',
                onPressed: () {
                  s.topUp(amount.toDouble());
                  Navigator.pop(c);
                  showToast(context,
                      'Le $amount added. Approve the prompt on your phone.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final activity = [
      ('Top up · Orange Money', '28 Oct', 200.0),
      ('Trip · Brookfields → Kissy', '25 Oct', -120.0),
      ('Referral bonus', '20 Oct', 20.0),
    ];
    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('Wallet', style: TS.h2),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: TR.brandGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                      color: TR.navy.fade(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 14)),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -30,
                    top: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.fade(0.12), width: 22),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(PhosphorIconsFill.wallet,
                            color: TR.greenBright, size: 20),
                        const SizedBox(width: 8),
                        Text('TrustRide balance',
                            style: TS.label.copyWith(
                                color: const Color(0xFFD6E2F0), fontSize: 14)),
                      ]),
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: s.wallet),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(TR.le(v, decimals: true),
                            style: TS.h1.copyWith(
                                color: Colors.white, fontSize: 36)),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        TRButton(
                          label: 'Top up',
                          kind: BtnKind.light,
                          expand: false,
                          height: 46,
                          icon: PhosphorIconsBold.plus,
                          onPressed: () => _topUp(context),
                        ),
                        const SizedBox(width: 10),
                        TRButton(
                          label: 'Send',
                          kind: BtnKind.dark,
                          expand: false,
                          height: 46,
                          icon: PhosphorIconsBold.paperPlaneTilt,
                          onPressed: () => showToast(
                              context, 'Send to a friend is coming soon'),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 22),
            const Caps('Payment methods'),
            const SizedBox(height: 10),
            TRCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final m in Mock.payMethods)
                  ListTile(
                    leading: PayDot(m.color, m.icon, size: 36),
                    title: Text(m.name, style: TS.label),
                    subtitle: Text(
                        m.id == 'wallet'
                            ? TR.le(s.wallet, decimals: true)
                            : m.detail,
                        style: TS.small),
                    trailing: s.paymentId == m.id
                        ? const Pill('Default')
                        : TextButton(
                            onPressed: () => s.setPayment(m.id),
                            child: Text('Set default',
                                style: TS.small.copyWith(
                                    color: TR.navy,
                                    fontWeight: FontWeight.w700)),
                          ),
                  ),
                ListTile(
                  leading: const IconBubble(PhosphorIconsBold.plus, size: 36),
                  title: Text('Add payment method',
                      style: TS.label.copyWith(color: TR.navy)),
                  onTap: () => showToast(context, 'Link Qmoney coming soon'),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const Caps('Recent activity'),
            const SizedBox(height: 10),
            TRCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final a in activity)
                  ListTile(
                    leading: IconBubble(
                      a.$3 > 0
                          ? PhosphorIconsBold.arrowDownLeft
                          : PhosphorIconsBold.arrowUpRight,
                      color: a.$3 > 0 ? TR.green : TR.navy,
                      bg: a.$3 > 0 ? TR.greenTint : TR.field,
                      size: 38,
                    ),
                    title: Text(a.$1, style: TS.label.copyWith(fontSize: 14)),
                    subtitle: Text(a.$2, style: TS.small),
                    trailing: Text(
                        '${a.$3 > 0 ? '+' : '−'}${TR.le(a.$3.abs(), decimals: true)}',
                        style: TS.label.copyWith(
                            color: a.$3 > 0 ? const Color(0xFF1F6B2E) : TR.ink)),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
