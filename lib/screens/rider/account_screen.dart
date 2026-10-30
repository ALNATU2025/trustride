import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    final d = s.driver;
    final nav = Navigator.of(context);
    if (p == null) return const Loading();

    final driverSub = d == null
        ? 'Earn on your own schedule'
        : switch (d.status) {
            'approved' => 'Open the driver app',
            'pending' => 'Application under review',
            'rejected' => 'Application needs changes',
            _ => 'Account ${d.status}',
          };

    final items = <(IconData, String, String, VoidCallback)>[
      (PhosphorIconsFill.userCircle, 'Personal info', 'Name, email, language',
          () => nav.pushNamed(R.profileSetup)),
      (PhosphorIconsFill.house, 'Home address', p.home?.label ?? 'Not set',
          () => nav.pushNamed(R.search, arguments: 'home')),
      (PhosphorIconsFill.briefcase, 'Work address', p.work?.label ?? 'Not set',
          () => nav.pushNamed(R.search, arguments: 'work')),
      (PhosphorIconsFill.shieldCheck, 'Safety centre',
          '${p.contacts.length} trusted contact${p.contacts.length == 1 ? '' : 's'}',
          () => nav.pushNamed(R.safety)),
      (PhosphorIconsFill.translate, 'Language', p.language, () async {
        final next = p.language == 'English' ? 'Krio' : 'English';
        await Db.setLanguage(p.uid, next);
        if (context.mounted) showToast(context, 'Language set to $next');
      }),
      (PhosphorIconsFill.headset, 'Help and support',
          s.config.supportPhone.isEmpty ? 'Coming soon' : s.config.supportPhone,
          () {
        if (s.config.supportPhone.isNotEmpty) {
          launchUrl(Uri(scheme: 'tel', path: s.config.supportPhone));
        }
      }),
      (PhosphorIconsFill.steeringWheel, 'Drive with TrustRide', driverSub,
          () => nav.pushNamed(d?.approved == true ? R.driver : R.driverSignup)),
      if (p.isAdmin)
        (PhosphorIconsFill.squaresFour, 'Admin console', 'Operations team',
            () => nav.pushNamed(R.admin)),
    ];

    return Container(
      color: TR.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(children: [
              Avatar(p.initials, size: 68, bg: TR.greenTint, fg: TR.green, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TS.h3.copyWith(fontSize: 20)),
                    Text(p.phone, style: TS.small),
                  ],
                ),
              ),
            ]).animate().fadeIn().slideX(begin: -0.05),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        IconBubble(items[i].$1, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].$2, style: TS.label),
                              Text(items[i].$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TS.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(PhosphorIconsBold.caretRight, size: 16, color: TR.subtle),
                      ]),
                    ),
                  ).animate().fadeIn(delay: (100 + i * 40).ms),
              ]),
            ),
            const SizedBox(height: 18),
            TRButton(
              label: 'Log out',
              kind: BtnKind.ghost,
              icon: PhosphorIconsBold.signOut,
              onPressed: () async {
                await s.signOut();
                nav.pushNamedAndRemoveUntil(R.signIn, (_) => false);
              },
            ),
            Center(
                child: Text('TrustRide v1.0.0',
                    style: TS.small.copyWith(fontSize: 11))),
          ],
        ),
      ),
    );
  }
}
