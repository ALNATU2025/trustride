import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class WalletTab extends StatefulWidget {
  const WalletTab({super.key});
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  Stream<List<WalletTx>>? _tx;
  String? _uid;

  void _howToTopUp(AppState s) {
    final phone = s.profile?.phone ?? '';
    final support = s.config.supportPhone;
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
            Text('Top up your wallet', style: TS.h3),
            const SizedBox(height: 10),
            Text(
                'Pay a TrustRide agent or our office in cash, and give them your account number below. The credit appears here straight away.',
                style: TS.body),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: TR.field, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your account number', style: TS.small),
                      Text(phone, style: TS.h3),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    Navigator.pop(c);
                    showToast(context, 'Account number copied');
                  },
                  child: Text('Copy', style: TS.label.copyWith(color: TR.navy)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            TRButton(
              label: support.isEmpty ? 'Agent line coming soon' : 'Call TrustRide',
              icon: PhosphorIconsFill.phoneCall,
              onPressed: support.isEmpty
                  ? null
                  : () => launchUrl(Uri(scheme: 'tel', path: support)),
            ),
            const SizedBox(height: 8),
            Text('Orange Money and Afrimoney top-ups are coming soon.',
                textAlign: TextAlign.center,
                style: TS.small.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final uid = s.authUser?.uid;
    if (uid != null && uid != _uid) {
      _uid = uid;
      _tx = Db.walletStream(uid);
    }
    final balance = s.profile?.wallet ?? 0;
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
                  BoxShadow(color: TR.navy.fade(0.3), blurRadius: 30, offset: const Offset(0, 14)),
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
                        border: Border.all(color: Colors.white.fade(0.12), width: 22),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(PhosphorIconsFill.wallet, color: TR.greenBright, size: 20),
                        const SizedBox(width: 8),
                        Text('TrustRide balance',
                            style: TS.label.copyWith(color: const Color(0xFFD6E2F0), fontSize: 14)),
                      ]),
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: balance),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(TR.le(v, decimals: true),
                            style: TS.h1.copyWith(color: Colors.white, fontSize: 36)),
                      ),
                      const SizedBox(height: 18),
                      TRButton(
                        label: 'Top up',
                        kind: BtnKind.light,
                        expand: false,
                        height: 46,
                        icon: PhosphorIconsBold.plus,
                        onPressed: () => _howToTopUp(s),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 22),
            const Caps('Activity'),
            const SizedBox(height: 10),
            StreamBuilder<List<WalletTx>>(
              stream: _tx,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EmptyState(
                      icon: PhosphorIconsFill.warning,
                      title: 'Couldn’t load activity');
                }
                if (!snap.hasData) return const Loading();
                final list = snap.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: PhosphorIconsFill.wallet,
                    title: 'No wallet activity yet',
                    body: 'Top-ups and wallet payments will show here.',
                  );
                }
                return TRCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final a in list)
                      ListTile(
                        leading: IconBubble(
                          a.amount > 0
                              ? PhosphorIconsBold.arrowDownLeft
                              : PhosphorIconsBold.arrowUpRight,
                          color: a.amount > 0 ? TR.green : TR.navy,
                          bg: a.amount > 0 ? TR.greenTint : TR.field,
                          size: 38,
                        ),
                        title: Text(
                            a.note.isNotEmpty
                                ? a.note
                                : (a.type == 'topup' ? 'Top up' : 'Payment'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.label.copyWith(fontSize: 14)),
                        subtitle: Text(dateLabel(a.createdAt), style: TS.small),
                        trailing: Text(
                            '${a.amount > 0 ? '+' : '−'}${TR.le(a.amount.abs(), decimals: true)}',
                            style: TS.label.copyWith(
                                color: a.amount > 0 ? const Color(0xFF1F6B2E) : TR.ink)),
                      ),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
