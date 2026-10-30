import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onOpenTab});
  final ValueChanged<int> onOpenTab;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final quick = [
      ('car', 'Car', PhosphorIconsFill.carProfile),
      ('keke', 'Keke', PhosphorIconsFill.scooter),
      ('okada', 'Okada', PhosphorIconsFill.motorcycle),
    ];
    final saved = [
      (PhosphorIconsFill.house, 'Home', 'Off Wilkinson Road, Congo Cross',
          Mock.places[8]),
      (PhosphorIconsFill.briefcase, 'Work', 'Siaka Stevens Street, Central',
          Mock.places[6]),
    ];

    return Stack(
      children: [
        const Positioned.fill(child: TRMap()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                CircleIconButton(
                  icon: PhosphorIconsBold.list,
                  label: 'Menu',
                  background: Colors.white,
                  shadow: true,
                  onTap: () => onOpenTab(3),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pushNamed(R.safety),
                  semanticLabel: 'Safety centre',
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: TR.shadow(),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.shieldCheck,
                          color: TR.green, size: 20),
                      const SizedBox(width: 6),
                      Text('Safety',
                          style: TS.label.copyWith(color: TR.green)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                CircleIconButton(
                  icon: PhosphorIconsBold.crosshair,
                  label: 'Recenter map',
                  background: Colors.white,
                  shadow: true,
                  onTap: () => showToast(context, 'Location: Congo Cross, Freetown',
                      icon: PhosphorIconsFill.mapPin),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.5),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomPanel(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 14),
                Text('${_greeting()},', style: TS.small),
                Text('Kushɛ, ${s.firstName}', style: TS.h2),
                const SizedBox(height: 14),
                Pressable(
                  scale: 0.98,
                  onTap: () => Navigator.of(context).pushNamed(R.search),
                  semanticLabel: 'Where to?',
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TR.field,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsBold.magnifyingGlass,
                          color: TR.navy, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Where to?',
                            style: TS.label
                                .copyWith(fontSize: 17, color: TR.muted)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(PhosphorIconsBold.clock, size: 15),
                          const SizedBox(width: 4),
                          Text('Now', style: TS.label.copyWith(fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < quick.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                          child: Pressable(
                            onTap: () {
                              s.setRide(quick[i].$1);
                              Navigator.of(context).pushNamed(R.search);
                            },
                            semanticLabel: quick[i].$2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [TR.greenTint, TR.greenTint.fade(0.5)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(children: [
                                Icon(quick[i].$3,
                                    color: i == 0 ? TR.navy : TR.green,
                                    size: 30),
                                const SizedBox(height: 4),
                                Text(quick[i].$2,
                                    style: TS.label.copyWith(fontSize: 13)),
                              ]),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: (200 + i * 80).ms)
                              .scale(begin: const Offset(0.85, 0.85)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final p in saved)
                  Pressable(
                    scale: 0.98,
                    onTap: () {
                      s.setDestination(p.$4);
                      Navigator.of(context).pushNamed(R.chooseRide);
                    },
                    semanticLabel: p.$2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        IconBubble(p.$1, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2, style: TS.label),
                              Text(p.$3, style: TS.small),
                            ],
                          ),
                        ),
                        const Icon(PhosphorIconsBold.caretRight,
                            size: 16, color: TR.subtle),
                      ]),
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: TR.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const Icon(PhosphorIconsFill.gift,
                        color: TR.greenBright, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Invite a friend — you both get Le 20 off',
                          style: TS.label
                              .copyWith(color: Colors.white, fontSize: 14)),
                    ),
                    const Icon(PhosphorIconsBold.arrowRight,
                        color: Colors.white, size: 18),
                  ]),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                        delay: 2500.ms,
                        duration: 1400.ms,
                        color: Colors.white.fade(0.25)),
              ],
            ),
          ).animate().slideY(
              begin: 0.4, duration: 550.ms, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}
