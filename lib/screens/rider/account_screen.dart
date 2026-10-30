import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final nav = Navigator.of(context);
    final initials =
        s.riderName.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();

    final items = <(IconData, String, String, VoidCallback)>[
      (PhosphorIconsFill.userCircle, 'Personal info', 'Name, photo, email',
          () => nav.pushNamed(R.profileSetup)),
      (PhosphorIconsFill.mapPin, 'Saved places', 'Home, Work + 2 more',
          () => nav.pushNamed(R.search)),
      (PhosphorIconsFill.shieldCheck, 'Safety centre',
          'Trusted contacts, SOS, ride PIN', () => nav.pushNamed(R.safety)),
      (PhosphorIconsFill.translate, 'Language', s.language, () {
        s.setProfile(s.riderName, s.language == 'English' ? 'Krio' : 'English');
        showToast(context, 'Language set to ${s.language}');
      }),
      (PhosphorIconsFill.headset, 'Help and support',
          'Call, WhatsApp or chat with us',
          () => showToast(context, 'Support line: +232 XX XXX XXX',
              icon: PhosphorIconsFill.headset)),
      (PhosphorIconsFill.steeringWheel, 'Drive with TrustRide',
          'Earn on your own schedule', () => nav.pushNamed(R.driverSignup)),
      (PhosphorIconsFill.squaresFour, 'Admin console',
          'Operations team only', () => nav.pushNamed(R.admin)),
    ];

    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(children: [
              Avatar(initials.toUpperCase(),
                  size: 68, bg: TR.greenTint, fg: TR.green, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.riderName, style: TS.h3.copyWith(fontSize: 20)),
                    Text('+232 ${s.phone}', style: TS.small),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: TR.shadow(0.5)),
                child: Row(children: [
                  const Icon(PhosphorIconsFill.star, color: TR.gold, size: 14),
                  Text(' 4.8', style: TS.label.copyWith(fontSize: 13)),
                ]),
              ),
            ]).animate().fadeIn().slideX(begin: -0.05),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [TR.green, Color(0xFF2E9B48)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(PhosphorIconsFill.gift,
                    color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite friends, ride for less',
                          style: TS.label.copyWith(color: Colors.white)),
                      Text('Code AMINATA20 — you both get Le 20',
                          style: TS.small.copyWith(
                              color: const Color(0xFFD6F0DA), fontSize: 12)),
                    ],
                  ),
                ),
                TRButton(
                  label: 'Copy',
                  kind: BtnKind.light,
                  expand: false,
                  height: 40,
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'AMINATA20'));
                    showToast(context, 'Invite code copied');
                  },
                ),
              ]),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
            const SizedBox(height: 18),
            TRCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (var i = 0; i < items.length; i++)
                  Pressable(
                    scale: 0.98,
                    onTap: items[i].$4,
                    semanticLabel: items[i].$2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        IconBubble(items[i].$1,
                            size: 40,
                            color: i == 6 ? TR.green : TR.navy,
                            bg: i == 6 ? TR.greenTint : TR.field),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].$2, style: TS.label),
                              Text(items[i].$3,
                                  style: TS.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(PhosphorIconsBold.caretRight,
                            size: 16, color: TR.subtle),
                      ]),
                    ),
                  ).animate().fadeIn(delay: (150 + i * 40).ms),
              ]),
            ),
            const SizedBox(height: 18),
            TRButton(
              label: 'Log out',
              kind: BtnKind.ghost,
              icon: PhosphorIconsBold.signOut,
              onPressed: () =>
                  nav.pushNamedAndRemoveUntil(R.signIn, (r) => false),
            ),
            Center(
                child: Text('TrustRide v1.0.0 · Freetown',
                    style: TS.small.copyWith(fontSize: 11))),
          ],
        ),
      ),
    );
  }
}
